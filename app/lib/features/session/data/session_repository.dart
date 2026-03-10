import 'dart:convert';
import 'dart:math';
import '../domain/session_entity.dart';
import '../domain/message_entity.dart';
import '../../../core/storage/session_dao.dart';
import '../../../core/storage/message_dao.dart';
import '../../../core/storage/task_dao.dart';
import '../../../core/storage/sync_queue_dao.dart';
import '../../../core/network/api_client.dart';

/// Local-first repository: writes go to local DB first, then queue for sync.
/// Reads always come from local DB for instant UI.
class SessionRepository {
  final SessionDao _sessionDao = SessionDao();
  final MessageDao _messageDao = MessageDao();
  final TaskDao _taskDao = TaskDao();
  final SyncQueueDao _syncQueueDao = SyncQueueDao();

  // ── Sessions ──

  Future<List<Session>> getAllSessions() async {
    final rows = await _sessionDao.getAllWithLastMessage();
    return rows.map((r) => Session.fromMap(r)).toList();
  }

  Future<Session> createSession({String? title}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _generateId();
    final session = {
      'id': id,
      'title': title,
      'created_at': now,
      'updated_at': now,
      'synced': 0,
    };
    await _sessionDao.insert(session);
    await _syncQueueDao.enqueue('create_session', jsonEncode({'id': id, 'title': title}));
    return Session.fromMap(session);
  }

  Future<void> updateSessionTitle(String sessionId, String title) async {
    await _sessionDao.update(sessionId, {
      'title': title,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'synced': 0,
    });
    await _syncQueueDao.enqueue('update_session', jsonEncode({'id': sessionId, 'title': title}));
  }

  Future<void> deleteSession(String sessionId) async {
    await _messageDao.deleteBySession(sessionId);
    await _taskDao.deleteBySession(sessionId);
    await _sessionDao.delete(sessionId);
    await _syncQueueDao.enqueue('delete_session', jsonEncode({'id': sessionId}));
  }

  // ── Messages ──

  Future<List<Message>> getMessages(String sessionId) async {
    final rows = await _messageDao.getBySession(sessionId);
    return rows.map((r) => Message.fromMap(r)).toList();
  }

  Future<Message> addUserMessage(String sessionId, String content) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _generateId();
    final msg = {
      'id': id,
      'session_id': sessionId,
      'role': 'user',
      'content': content,
      'task_id': null,
      'created_at': now,
      'synced': 0,
    };
    await _messageDao.insert(msg);

    await _sessionDao.update(sessionId, {
      'updated_at': now,
      'synced': 0,
    });

    await _syncQueueDao.enqueue('send_command', jsonEncode({
      'session_id': sessionId,
      'message_id': id,
      'text': content,
    }));

    return Message.fromMap(msg);
  }

  Future<Message> addAssistantMessage(
    String sessionId,
    String content, {
    String? taskId,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _generateId();
    final msg = {
      'id': id,
      'session_id': sessionId,
      'role': 'assistant',
      'content': content,
      'task_id': taskId,
      'type': type.value,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': now,
      'synced': 1,
    };
    await _messageDao.insert(msg);
    return Message.fromMap(msg);
  }

  Future<void> followUp(String taskId, String text) async {
    await apiClient.followUp(taskId, text);
  }

  Future<void> confirmTask(String taskId) async {
    await apiClient.confirmTask(taskId);
  }

  Future<void> cancelTask(String taskId) async {
    await apiClient.cancelTask(taskId);
  }

  Future<void> retryTask(String taskId) async {
    await apiClient.retryTask(taskId);
  }

  // ── Tasks ──

  Future<List<Map<String, dynamic>>> getTasksBySession(String sessionId) async {
    return _taskDao.getBySession(sessionId);
  }

  Future<void> upsertTask(Map<String, dynamic> task) async {
    await _taskDao.upsert(task);
  }

  Future<Map<String, dynamic>?> getTask(String taskId) async {
    return _taskDao.getById(taskId);
  }

  // ── Helpers ──

  static String _generateId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
