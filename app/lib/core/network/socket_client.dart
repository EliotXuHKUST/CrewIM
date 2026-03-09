import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../config/env.dart';

/// WebSocket client with auto-reconnect.
/// Uses dart:io WebSocket directly; swap for web_socket_channel package
/// when dependencies are installed via `flutter pub add web_socket_channel`.
class SocketClient {
  WebSocket? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  String? _token;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30;

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  void connect(String token) {
    _token = token;
    _reconnectAttempts = 0;
    _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed || _token == null) return;

    try {
      _channel = await WebSocket.connect(Env.wsBaseUrl);

      _channel!.listen(
        (data) {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          if (message['type'] == 'auth_ok') {
            _reconnectAttempts = 0;
            return;
          }
          _eventController.add(message);
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );

      _channel!.add(jsonEncode({'type': 'auth', 'token': _token}));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onDisconnect() {
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (_reconnectAttempts < 5)
          ? (1 << _reconnectAttempts)
          : _maxReconnectDelay,
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _eventController.close();
  }
}
