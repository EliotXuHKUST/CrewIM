import 'dart:convert';
import 'dart:io';
import '../config/env.dart';
import '../storage/auth_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;
}

class ApiClient {
  String? _token;

  String? get token => _token;
  bool get isLoggedIn => _token != null;

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retry401 = true,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}$path').replace(queryParameters: query);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      late HttpClientRequest request;
      switch (method) {
        case 'GET':
          request = await client.getUrl(uri);
        case 'POST':
          request = await client.postUrl(uri);
        case 'PUT':
          request = await client.putUrl(uri);
        case 'DELETE':
          request = await client.deleteUrl(uri);
        default:
          request = await client.getUrl(uri);
      }

      request.headers.set('Content-Type', 'application/json');
      if (_token != null) {
        request.headers.set('Authorization', 'Bearer $_token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 401 && retry401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          return _request(method, path, body: body, query: query, retry401: false);
        }
        await _handleLogout();
        throw ApiException(401, '登录已过期，请重新登录');
      }

      if (response.statusCode >= 400) {
        String errorMsg = '请求失败';
        try {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          errorMsg = decoded['error'] as String? ?? errorMsg;
        } catch (_) {}
        throw ApiException(response.statusCode, errorMsg);
      }

      if (responseBody.isEmpty) return {};
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } on SocketException {
      throw ApiException(0, '网络连接失败，请检查网络');
    } on HttpException catch (e) {
      throw ApiException(0, e.message);
    } finally {
      client.close();
    }
  }

  Future<bool> _tryRefreshToken() async {
    if (_token == null) return false;
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/auth/refresh');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $_token');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final newToken = decoded['token'] as String?;
        if (newToken != null) {
          _token = newToken;
          await AuthStorage.saveToken(newToken);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _handleLogout() async {
    _token = null;
    await AuthStorage.clear();
  }

  // ── Auth ──

  Future<Map<String, dynamic>> sendSmsCode(String phone) async {
    return _request('POST', '/api/auth/sms-code', body: {'phone': phone});
  }

  Future<Map<String, dynamic>> login(String phone, String code) async {
    final result = await _request('POST', '/api/auth/login', body: {
      'phone': phone,
      'code': code,
    });
    if (result['token'] != null) {
      _token = result['token'] as String;
    }
    return result;
  }

  Future<Map<String, dynamic>> deleteMyAccount() async {
    return _request('DELETE', '/api/auth/account');
  }

  // ── Sessions ──

  Future<Map<String, dynamic>> createSession({required String id, String? title}) async {
    return _request('POST', '/api/sessions', body: {'id': id, 'title': title});
  }

  Future<Map<String, dynamic>> getSessions() async {
    return _request('GET', '/api/sessions');
  }

  Future<Map<String, dynamic>> updateSession({required String id, required String title}) async {
    return _request('PUT', '/api/sessions/$id', body: {'title': title});
  }

  Future<Map<String, dynamic>> deleteSession({required String id}) async {
    return _request('DELETE', '/api/sessions/$id');
  }

  // ── Commands ──

  Future<Map<String, dynamic>> sendCommand(String text, {String? sessionId}) async {
    final body = <String, dynamic>{'text': text};
    if (sessionId != null) body['session_id'] = sessionId;
    return _request('POST', '/api/commands', body: body);
  }

  Future<Map<String, dynamic>> sendCommandWithMedia({
    String? text,
    String? audioPath,
    List<String>? imagePaths,
    String? sessionId,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}/api/commands');
    final request = HttpClient();
    request.connectionTimeout = const Duration(seconds: 30);

    try {
      final boundary = 'boundary${DateTime.now().millisecondsSinceEpoch}';
      final httpRequest = await request.postUrl(uri);
      httpRequest.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
      if (_token != null) {
        httpRequest.headers.set('Authorization', 'Bearer $_token');
      }

      final body = <int>[];

      void addField(String name, String value) {
        body.addAll('--$boundary\r\n'.codeUnits);
        body.addAll('Content-Disposition: form-data; name="$name"\r\n\r\n'.codeUnits);
        body.addAll('$value\r\n'.codeUnits);
      }

      Future<void> addFile(String name, String filePath) async {
        final file = File(filePath);
        final filename = filePath.split('/').last;
        final bytes = await file.readAsBytes();
        body.addAll('--$boundary\r\n'.codeUnits);
        body.addAll('Content-Disposition: form-data; name="$name"; filename="$filename"\r\n'.codeUnits);
        body.addAll('Content-Type: application/octet-stream\r\n\r\n'.codeUnits);
        body.addAll(bytes);
        body.addAll('\r\n'.codeUnits);
      }

      if (text != null && text.isNotEmpty) addField('text', text);
      if (sessionId != null) addField('session_id', sessionId);
      if (audioPath != null) await addFile('audio', audioPath);
      if (imagePaths != null) {
        for (final path in imagePaths) {
          await addFile('images', path);
        }
      }

      body.addAll('--$boundary--\r\n'.codeUnits);
      httpRequest.add(body);

      final response = await httpRequest.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        throw ApiException(response.statusCode, 'Upload failed');
      }

      if (responseBody.isEmpty) return {};
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } on SocketException {
      throw ApiException(0, '网络连接失败');
    } finally {
      request.close();
    }
  }

  Future<Map<String, dynamic>> followUp(String taskId, String text) async {
    return _request('POST', '/api/commands/$taskId/follow-up', body: {'text': text});
  }

  // ── Tasks ──

  Future<Map<String, dynamic>> getTasks({String? status, String? sessionId, int page = 1, int limit = 20}) async {
    final query = <String, String>{'page': '$page', 'limit': '$limit'};
    if (status != null) query['status'] = status;
    if (sessionId != null) query['session_id'] = sessionId;
    return _request('GET', '/api/tasks', query: query);
  }

  Future<Map<String, dynamic>> getTaskDetail(String taskId) async {
    return _request('GET', '/api/tasks/$taskId');
  }

  Future<Map<String, dynamic>> confirmTask(String taskId) async {
    return _request('POST', '/api/tasks/$taskId/confirm');
  }

  Future<Map<String, dynamic>> cancelTask(String taskId) async {
    return _request('POST', '/api/tasks/$taskId/cancel');
  }

  Future<Map<String, dynamic>> retryTask(String taskId) async {
    return _request('POST', '/api/tasks/$taskId/retry');
  }

  // ── Profile ──

  Future<Map<String, dynamic>> getProfile() async {
    return _request('GET', '/api/profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profile) async {
    return _request('PUT', '/api/profile', body: profile);
  }

  // ── Accounts ──

  Future<Map<String, dynamic>> getAccounts() async {
    return _request('GET', '/api/accounts');
  }

  Future<Map<String, dynamic>> createAccount({
    required String platform,
    String? displayName,
    required Map<String, dynamic> credentials,
  }) async {
    return _request('POST', '/api/accounts', body: {
      'platform': platform,
      'display_name': displayName,
      'credentials': credentials,
    });
  }

  Future<Map<String, dynamic>> updateAccount({
    required String id,
    String? displayName,
    Map<String, dynamic>? credentials,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (credentials != null) body['credentials'] = credentials;
    return _request('PUT', '/api/accounts/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteAccount(String id) async {
    return _request('DELETE', '/api/accounts/$id');
  }
}

final apiClient = ApiClient();
