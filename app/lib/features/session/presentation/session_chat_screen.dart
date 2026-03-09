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

  Future<void> _handleWsEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    if (type == null || type == 'auth_ok') return;

    final task = event['task'] as Map<String, dynamic>?;
    if (task == null) return;

    final taskSessionId = task['sessionId'] as String? ?? task['session_id'] as String?;
    if (taskSessionId != null && taskSessionId != _currentSessionId) return;

    final String content;
    switch (type) {
      case 'task_understanding':
        content = '正在理解：${task['understanding'] ?? '...'}';
      case 'task_progress':
        content = task['progress'] as String? ?? '执行中…';
      case 'task_completed':
        final result = task['result'];
        if (result is Map) {
          content = '已完成：${result['body'] ?? result['summary'] ?? ''}';
        } else {
          content = '任务已完成';
        }
      case 'task_failed':
        content = '执行失败：${task['error'] ?? '未知错误'}';
      case 'task_waiting_confirm':
        content = '需要确认：${task['understanding'] ?? ''}';
      default:
        return;
    }

    if (content.isNotEmpty && _currentSessionId != null) {
      final msg = await _repo.addAssistantMessage(
        _currentSessionId!,
        content,
        taskId: task['id'] as String?,
      );
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendText(String text) async {
    if (_currentSessionId == null) return;

    final msg = await _repo.addUserMessage(_currentSessionId!, text);
    setState(() => _messages.add(msg));
    _scrollToBottom();

    try {
      await apiClient.sendCommand(text, sessionId: _currentSessionId);
    } catch (e) {
      debugPrint('Send command failed (queued for sync): $e');
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
      debugPrint('Send media failed: $e');
    }

    _loadAll();
  }

  Future<void> _switchToSession(String sessionId) async {
    setState(() {
      _currentSessionId = sessionId;
      _messages = [];
      _loading = true;
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
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _messages.isEmpty
                      ? SceneCards(onTap: _sendText)
                      : _buildMessageList(),
            ),
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
        );
      },
    );
  }
}
