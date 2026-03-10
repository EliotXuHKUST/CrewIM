import 'dart:convert';

class Message {
  final String id;
  final String sessionId;
  final MessageRole role;
  final String content;
  final String? taskId;
  final MessageType type;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool synced;

  Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.taskId,
    this.type = MessageType.text,
    this.metadata,
    required this.createdAt,
    this.synced = false,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? meta;
    final rawMeta = map['metadata'];
    if (rawMeta is String && rawMeta.isNotEmpty) {
      try {
        meta = jsonDecode(rawMeta) as Map<String, dynamic>;
      } catch (_) {}
    } else if (rawMeta is Map<String, dynamic>) {
      meta = rawMeta;
    }

    return Message(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: MessageRole.fromString(map['role'] as String),
      content: map['content'] as String,
      taskId: map['task_id'] as String?,
      type: MessageType.fromString(map['type'] as String? ?? 'text'),
      metadata: meta,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'role': role.value,
    'content': content,
    'task_id': taskId,
    'type': type.value,
    'metadata': metadata != null ? jsonEncode(metadata) : null,
    'created_at': createdAt.toUtc().toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isTaskCard => type != MessageType.text;
}

enum MessageRole {
  user('user'),
  assistant('assistant');

  final String value;
  const MessageRole(this.value);

  static MessageRole fromString(String s) =>
      s == 'user' ? MessageRole.user : MessageRole.assistant;
}

enum MessageType {
  text('text'),
  taskUnderstanding('task_understanding'),
  taskProgress('task_progress'),
  taskWaitingConfirm('task_waiting_confirm'),
  taskCompleted('task_completed'),
  taskFailed('task_failed');

  final String value;
  const MessageType(this.value);

  static MessageType fromString(String s) {
    return MessageType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => MessageType.text,
    );
  }
}
