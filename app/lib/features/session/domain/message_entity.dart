class Message {
  final String id;
  final String sessionId;
  final MessageRole role;
  final String content;
  final String? taskId;
  final DateTime createdAt;
  final bool synced;

  Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.taskId,
    required this.createdAt,
    this.synced = false,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: MessageRole.fromString(map['role'] as String),
      content: map['content'] as String,
      taskId: map['task_id'] as String?,
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
    'created_at': createdAt.toUtc().toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
}

enum MessageRole {
  user('user'),
  assistant('assistant');

  final String value;
  const MessageRole(this.value);

  static MessageRole fromString(String s) =>
      s == 'user' ? MessageRole.user : MessageRole.assistant;
}
