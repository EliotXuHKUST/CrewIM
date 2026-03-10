import 'dart:async';
import 'socket_client.dart';
import 'api_client.dart';

typedef WsEventCallback = void Function(Map<String, dynamic> event);

class SocketManager {
  SocketManager._();
  static final instance = SocketManager._();

  SocketClient? _client;
  StreamSubscription? _sub;
  final _listeners = <String, Set<WsEventCallback>>{};
  final _globalListeners = <WsEventCallback>{};

  bool get isConnected => _client != null;

  void connect() {
    if (_client != null || apiClient.token == null) return;
    _client = SocketClient(() => apiClient.token);
    _sub = _client!.eventStream.listen(_dispatch);
    _client!.connect();
  }

  void disconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.dispose();
    _client = null;
  }

  void reconnect() {
    disconnect();
    connect();
  }

  void addListener(String? sessionId, WsEventCallback callback) {
    if (sessionId == null) {
      _globalListeners.add(callback);
    } else {
      _listeners.putIfAbsent(sessionId, () => {}).add(callback);
    }
  }

  void removeListener(String? sessionId, WsEventCallback callback) {
    if (sessionId == null) {
      _globalListeners.remove(callback);
    } else {
      _listeners[sessionId]?.remove(callback);
      if (_listeners[sessionId]?.isEmpty ?? false) {
        _listeners.remove(sessionId);
      }
    }
  }

  void _dispatch(Map<String, dynamic> event) {
    for (final cb in _globalListeners) {
      cb(event);
    }

    final task = event['task'] as Map<String, dynamic>?;
    final sessionId = task?['sessionId'] as String? ?? task?['session_id'] as String?;
    if (sessionId != null && _listeners.containsKey(sessionId)) {
      for (final cb in _listeners[sessionId]!) {
        cb(event);
      }
    }
  }
}
