import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_manager.dart';
import '../data/session_repository.dart';
import '../domain/session_entity.dart';
import '../domain/message_entity.dart';
import '../../command/presentation/widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/task_cards.dart';
import 'widgets/scene_cards.dart';
import 'widgets/nav_drawer.dart';

class SessionChatScreen extends StatefulWidget {
  final String? sessionId;

  const SessionChatScreen({super.key, this.sessionId});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repo = SessionRepository();
  final _scrollController = ScrollController();

  String? _currentSessionId;
  Session? _session;
  List<Session> _allSessions = [];
  List<Message> _messages = [];
  bool _loading = true;

  // Pending confirmation tasks (for the top banner)
  List<_PendingTask> _pendingTasks = [];

  // Follow-up state
  String? _followUpTaskId;

  @override
  void initState() {
    super.initState();
    SocketManager.instance.connect();
    SocketManager.instance.addListener(null, _onGlobalEvent);
    _init();
  }

  @override
  void dispose() {
    SocketManager.instance.removeListener(null, _onGlobalEvent);
    _scrollController.dispose();
    super.dispose();
  }

  void _onGlobalEvent(Map<String, dynamic> event) {
    _handleWsEvent(event);
  }

  Future<void> _init() async {
    if (widget.sessionId != null) {
      _currentSessionId = widget.sessionId;
    } else {
      final session = await _repo.createSession();
      _currentSessionId = session.id;
    }

    await _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final allSessions = await _repo.getAllSessions();
      final session = allSessions.where((s) => s.id == _currentSessionId).firstOrNull;
      final messages = _currentSessionId != null
          ? await _repo.getMessages(_currentSessionId!)
          : <Message>[];

      _rebuildPendingTasks(messages);

      if (mounted) {
        setState(() {
          _allSessions = allSessions;
          _session = session;
          _messages = messages;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _rebuildPendingTasks(List<Message> messages) {
    final pending = <_PendingTask>[];
    final confirmedIds = <String>{};

    for (final m in messages.reversed) {
      if (m.taskId == null) continue;
      if (m.type == MessageType.taskWaitingConfirm) {
        final confirmed = m.metadata?['confirmed'] as bool? ?? false;
        if (confirmed) {
          confirmedIds.add(m.taskId!);
        } else if (!confirmedIds.contains(m.taskId!)) {
          pending.add(_PendingTask(
            taskId: m.taskId!,
            understanding: m.metadata?['understanding'] as String? ?? m.content,
          ));
        }
      }
      if (m.type == MessageType.taskCompleted ||
          m.type == MessageType.taskFailed) {
        confirmedIds.add(m.taskId!);
      }
    }
    _pendingTasks = pending.reversed.toList();
  }

  Future<void> _handleWsEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    if (type == null || type == 'auth_ok' || type == 'auth_error') return;

    if (type == 'session_updated') {
      final sid = event['sessionId'] as String?;
      final title = event['title'] as String?;
      if (sid != null && title != null && sid == _currentSessionId) {
        setState(() {
          _session = Session(
            id: _session!.id,
            title: title,
            createdAt: _session!.createdAt,
            updatedAt: DateTime.now(),
            synced: _session!.synced,
          );
        });
        await _repo.updateSessionTitle(sid, title);
      }
      return;
    }

    final task = event['task'] as Map<String, dynamic>?;
    final taskId = task?['id'] as String? ?? event['taskId'] as String?;
    if (taskId == null) return;

    final taskSessionId = task?['sessionId'] as String? ?? task?['session_id'] as String?;
    if (taskSessionId != null && taskSessionId != _currentSessionId) return;

    final message = event['message'] as String? ?? '';

    switch (type) {
      case 'task_understanding':
        final understanding = task?['understanding'] as String? ?? message;
        if (understanding.isEmpty) return;
        final steps = task?['steps'] as List<dynamic>?;
        await _addTypedMessage(
          content: understanding,
          taskId: taskId,
          type: MessageType.taskUnderstanding,
          metadata: {
            'understanding': understanding,
            if (steps != null) 'steps': steps,
          },
        );

      case 'task_progress':
        final progress = message.isNotEmpty ? message : '执行中…';
        final step = event['step'] as String? ?? progress;
        await _addTypedMessage(
          content: progress,
          taskId: taskId,
          type: MessageType.taskProgress,
          metadata: {'step': step},
        );

      case 'task_completed':
        final result = event['result'] as Map<String, dynamic>? ?? task?['result'] as Map<String, dynamic>?;
        String resultTitle = '执行结果';
        String resultBody = '任务已完成';
        if (result != null) {
          resultTitle = (result['title'] as String?) ?? '执行结果';
          resultBody = (result['body'] as String?) ?? (result['summary'] as String?) ?? '任务已完成';
        }
        await _addTypedMessage(
          content: resultBody,
          taskId: taskId,
          type: MessageType.taskCompleted,
          metadata: {'resultTitle': resultTitle, 'resultBody': resultBody},
        );

      case 'task_failed':
        final error = event['reason'] as String? ?? task?['error'] as String? ?? '未知错误';
        await _addTypedMessage(
          content: error,
          taskId: taskId,
          type: MessageType.taskFailed,
          metadata: {'error': error},
        );

      case 'task_waiting_confirm':
        final understanding = task?['understanding'] as String? ?? message;
        final confirmMsg = message.isNotEmpty ? message : understanding;
        await _addTypedMessage(
          content: confirmMsg,
          taskId: taskId,
          type: MessageType.taskWaitingConfirm,
          metadata: {
            'understanding': understanding,
            'confirmMessage': confirmMsg,
            'confirmed': false,
          },
        );
        setState(() {
          _pendingTasks.add(_PendingTask(taskId: taskId, understanding: understanding));
        });

      default:
        return;
    }
  }

  Future<void> _addTypedMessage({
    required String content,
    String? taskId,
    required MessageType type,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentSessionId == null) return;

    final msg = await _repo.addAssistantMessage(
      _currentSessionId!,
      content,
      taskId: taskId,
      type: type,
      metadata: metadata,
    );
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  Future<void> _handleTaskAction(String taskId, String action, {String? text}) async {
    switch (action) {
      case 'confirm':
        try {
          await _repo.confirmTask(taskId);
          _markConfirmResolved(taskId);
          await _addTypedMessage(
            content: '已确认，开始执行',
            taskId: taskId,
            type: MessageType.taskProgress,
            metadata: {'step': '任务已确认，正在执行…'},
          );
        } catch (e) {
          _showError('确认失败：$e');
        }

      case 'cancel':
        try {
          await _repo.cancelTask(taskId);
          _markConfirmResolved(taskId);
          await _addTypedMessage(
            content: '已取消',
            taskId: taskId,
            type: MessageType.taskFailed,
            metadata: {'error': '任务已取消'},
          );
        } catch (e) {
          _showError('取消失败：$e');
        }

      case 'retry':
        try {
          await _repo.retryTask(taskId);
          await _addTypedMessage(
            content: '正在重试…',
            taskId: taskId,
            type: MessageType.taskProgress,
            metadata: {'step': '重新理解指令中…'},
          );
        } catch (e) {
          _showError('重试失败：$e');
        }

      case 'follow_up':
        setState(() => _followUpTaskId = taskId);

      case 'to_doc':
        if (text != null) {
          await _sendFollowUp(taskId, '请把以下结果整理成文档：\n$text');
        }

      case 'remind':
        if (text != null) {
          await _sendFollowUp(taskId, '请帮我设一个提醒：关于"$text"');
        }

      case 'detail':
        if (mounted) {
          Navigator.pushNamed(context, '/task/$taskId');
        }
    }
  }

  void _markConfirmResolved(String taskId) {
    setState(() {
      _pendingTasks.removeWhere((p) => p.taskId == taskId);
      // Mark the confirm card as resolved
      for (int i = _messages.length - 1; i >= 0; i--) {
        final m = _messages[i];
        if (m.taskId == taskId && m.type == MessageType.taskWaitingConfirm) {
          final updated = Message(
            id: m.id,
            sessionId: m.sessionId,
            role: m.role,
            content: m.content,
            taskId: m.taskId,
            type: m.type,
            metadata: {...?m.metadata, 'confirmed': true},
            createdAt: m.createdAt,
            synced: m.synced,
          );
          _messages[i] = updated;
          break;
        }
      }
    });
  }

  Future<void> _sendFollowUp(String taskId, String text) async {
    if (_currentSessionId == null) return;

    final msg = await _repo.addUserMessage(_currentSessionId!, text);
    setState(() {
      _messages.add(msg);
      _followUpTaskId = null;
    });
    _scrollToBottom();

    try {
      await _repo.followUp(taskId, text);
    } catch (e) {
      _showError('补充发送失败：$e');
    }

    _loadAll();
  }

  Future<void> _sendText(String text) async {
    if (_followUpTaskId != null) {
      await _sendFollowUp(_followUpTaskId!, text);
      return;
    }

    if (_currentSessionId == null) return;

    final msg = await _repo.addUserMessage(_currentSessionId!, text);
    setState(() => _messages.add(msg));
    _scrollToBottom();

    try {
      await apiClient.sendCommand(text, sessionId: _currentSessionId);
    } catch (e) {
      _showError('指令发送失败：$e');
    }

    _loadAll();
  }

  Future<void> _sendMedia({String? audioPath, List<String>? imagePaths}) async {
    if (_currentSessionId == null) return;

    final label = audioPath != null ? '语音指令发送中…' : '图片上传中…';
    final msg = await _repo.addUserMessage(_currentSessionId!, label);
    setState(() => _messages.add(msg));
    _scrollToBottom();

    try {
      await apiClient.sendCommandWithMedia(
        audioPath: audioPath,
        imagePaths: imagePaths,
        sessionId: _currentSessionId,
      );
    } catch (e) {
      _showError('上传失败：$e');
    }

    _loadAll();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _switchToSession(String sessionId) async {
    setState(() {
      _currentSessionId = sessionId;
      _messages = [];
      _loading = true;
      _followUpTaskId = null;
      _pendingTasks = [];
    });
    await _loadAll();
  }

  Future<void> _createNewSession() async {
    final session = await _repo.createSession();
    await _switchToSession(session.id);
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定删除这个会话？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteSession(sessionId);
      if (sessionId == _currentSessionId) {
        await _createNewSession();
      } else {
        await _loadAll();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Scaffold(
      key: _scaffoldKey,
      drawer: NavDrawer(
        sessions: _allSessions,
        currentSessionId: _currentSessionId,
        onNewSession: _createNewSession,
        onSessionTap: _switchToSession,
        onSessionDelete: _deleteSession,
        onSettings: () => Navigator.pushNamed(context, '/settings'),
        onProfile: () => Navigator.pushNamed(context, '/settings'),
      ),
      drawerEdgeDragWidth: 40,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(textColor, isDark),
            if (_pendingTasks.isNotEmpty) _buildPendingBanner(isDark),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _messages.isEmpty
                      ? SceneCards(onTap: _sendText)
                      : _buildMessageList(),
            ),
            if (_followUpTaskId != null)
              FollowUpInput(
                taskId: _followUpTaskId!,
                onSubmit: (text) => _sendFollowUp(_followUpTaskId!, text),
                onCancel: () => setState(() => _followUpTaskId = null),
              )
            else
              ChatInputBar(
                onSubmitText: _sendText,
                onSubmitMedia: ({String? audioPath, List<String>? imagePaths}) {
                  _sendMedia(audioPath: audioPath, imagePaths: imagePaths);
                },
                onFile: () {},
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color textColor, bool isDark) {
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final separatorColor = isDark ? AppColors.separatorDark : AppColors.separator;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.background,
        border: Border(
          bottom: BorderSide(color: separatorColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Icon(Icons.menu_rounded, size: 22, color: secondaryColor),
          ),
          Expanded(
            child: Center(
              child: Text(
                _messages.isEmpty ? '知知' : (_session?.displayTitle ?? '知知'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textColor, letterSpacing: -0.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            onPressed: _createNewSession,
            icon: Icon(Icons.edit_square, size: 20, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(bool isDark) {
    final count = _pendingTasks.length;
    final first = _pendingTasks.first;

    return GestureDetector(
      onTap: () => _scrollToPendingTask(first.taskId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1A12) : const Color(0xFFFEFCE8),
          border: Border(
            bottom: BorderSide(
              color: AppColors.warning.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 1
                    ? '1 项待拍板：${first.understanding}'
                    : '$count 项待拍板',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.warning),
          ],
        ),
      ),
    );
  }

  void _scrollToPendingTask(String taskId) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].taskId == taskId &&
          _messages[i].type == MessageType.taskWaitingConfirm) {
        final offset = i * 80.0; // approximate
        _scrollController.animateTo(
          offset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        break;
      }
    }
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final prev = _messages[index - 1].createdAt;
    final curr = _messages[index].createdAt;
    return curr.difference(prev).inMinutes > 3;
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return ChatMessageBubble(
          message: _messages[index],
          showTimestamp: _shouldShowTimestamp(index),
          onTaskAction: _handleTaskAction,
        );
      },
    );
  }
}

class _PendingTask {
  final String taskId;
  final String understanding;
  _PendingTask({required this.taskId, required this.understanding});
}
