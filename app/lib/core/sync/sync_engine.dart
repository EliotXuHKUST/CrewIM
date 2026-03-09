import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../storage/sync_queue_dao.dart';
import '../network/api_client.dart';

enum SyncStatus { idle, syncing, offline }

class SyncEngine {
  final SyncQueueDao _queueDao = SyncQueueDao();
  final ApiClient _api;

  Timer? _timer;
  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;
  static const _interval = Duration(seconds: 5);
  static const _maxRetries = 5;

  SyncEngine(this._api);

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Trigger an immediate sync (e.g. on network recovery or app foreground).
  Future<void> flush() async {
    if (_status == SyncStatus.syncing) return;
    _setStatus(SyncStatus.syncing);

    try {
      await _processQueue();
      _setStatus(SyncStatus.idle);
    } catch (e) {
      debugPrint('[SyncEngine] flush error: $e');
      _setStatus(SyncStatus.offline);
    }
  }

  Future<void> _processQueue() async {
    while (true) {
      final batch = await _queueDao.peekBatch(limit: 5);
      if (batch.isEmpty) break;

      final completedIds = <int>[];

      for (final item in batch) {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        final retries = (item['retries'] as int?) ?? 0;

        if (retries >= _maxRetries) {
          completedIds.add(id);
          debugPrint('[SyncEngine] Dropping item $id after $retries retries');
          continue;
        }

        try {
          await _execute(action, payload);
          completedIds.add(id);
        } catch (e) {
          debugPrint('[SyncEngine] Failed action=$action id=$id: $e');
          await _queueDao.incrementRetries(id);
          rethrow;
        }
      }

      if (completedIds.isNotEmpty) {
        await _queueDao.removeCompleted(completedIds);
      }
    }
  }

  Future<void> _execute(String action, Map<String, dynamic> payload) async {
    switch (action) {
      case 'create_session':
        await _api.createSession(
          id: payload['id'] as String,
          title: payload['title'] as String?,
        );
      case 'update_session':
        await _api.updateSession(
          id: payload['id'] as String,
          title: payload['title'] as String,
        );
      case 'delete_session':
        await _api.deleteSession(id: payload['id'] as String);
      case 'send_command':
        await _api.sendCommand(
          payload['text'] as String,
          sessionId: payload['session_id'] as String?,
        );
      case 'confirm_task':
        await _api.confirmTask(payload['task_id'] as String);
      case 'cancel_task':
        await _api.cancelTask(payload['task_id'] as String);
      default:
        debugPrint('[SyncEngine] Unknown action: $action');
    }
  }

  void _setStatus(SyncStatus s) {
    if (_status != s) {
      _status = s;
      _statusController.add(s);
    }
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}
