class Session {
  final String id;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  Session({
    required this.id,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      title: map['title'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      synced: (map['synced'] as int?) == 1,
      lastMessage: map['last_message'] as String?,
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  String get displayTitle => title ?? '新会话';

  String get displayTime {
    final target = lastMessageAt ?? updatedAt;
    final now = DateTime.now();
    final local = target.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (date == today.subtract(const Duration(days: 1))) {
      return '昨天';
    }
    return '${local.month}月${local.day}日';
  }
}
