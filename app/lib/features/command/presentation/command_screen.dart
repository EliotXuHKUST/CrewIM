import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_manager.dart';
import '../../task/presentation/widgets/task_card.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/history_drawer.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  bool _connected = false;
  String? _errorBanner;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    SocketManager.instance.connect();
    SocketManager.instance.addListener(null, _onWsEvent);
    _connected = SocketManager.instance.isConnected;
    _init();
  }

  @override
  void dispose() {
    SocketManager.instance.removeListener(null, _onWsEvent);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type != null && type.startsWith('task_')) {
      _loadTasks();
    }
  }

  Future<void> _init() async {
    try {
      await _loadTasks();
      _startPolling();
    } catch (e) {
      debugPrint('Init failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final result = await apiClient.getTasks(limit: 50);
      final tasks = (result['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _tasks = tasks; _loading = false; });
    } catch (e) {
      debugPrint('Load tasks failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadTasks());
  }

  Future<void> _sendCommand(String text) async {
    setState(() => _errorBanner = null);
    try {
      await apiClient.sendCommand(text);
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        setState(() => _errorBanner = '发送失败，请重试');
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _errorBanner = null);
        });
      }
    }
  }

  Future<void> _confirmTask(String id) async {
    await apiClient.confirmTask(id);
    _loadTasks();
  }

  Future<void> _cancelTask(String id) async {
    await apiClient.cancelTask(id);
    _loadTasks();
  }

  Future<void> _retryTask(String id) async {
    await apiClient.retryTask(id);
    _loadTasks();
  }

  void _onCamera() => _sendCommand('[拍照指令] 请分析我拍摄的内容');
  void _onPhotoLibrary() => _sendCommand('[相册图片] 请分析这张图片');
  void _onFile() => _sendCommand('[文件上传] 请处理这个文件');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: HistoryDrawer(
        tasks: _tasks,
        onTaskTap: (id) => Navigator.pushNamed(context, '/task/$id'),
      ),
      drawerEdgeDragWidth: 40,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            if (_errorBanner != null) _buildErrorBanner(isDark),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _tasks.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildTaskList(isDark),
            ),
            _buildBottomArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Icon(Icons.menu_rounded, size: 22, color: secondaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            '指挥台',
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w500,
              color: textColor, letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _connected ? AppColors.success : AppColors.textPlaceholder,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _connected ? '在线' : '离线',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w400,
                  color: _connected ? AppColors.success : AppColors.textPlaceholder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      color: AppColors.error.withAlpha(isDark ? 25 : 15),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            _errorBanner!,
            style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none_rounded, size: 32, color: secondaryColor),
          const SizedBox(height: 16),
          Text(
            '按住说话，发出你的第一条指令',
            style: TextStyle(fontSize: 15, color: secondaryColor, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 6),
          Text(
            '也可以输入文字、拍照或上传文件',
            style: TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final t = _tasks[index];
          final status = t['status'] as String? ?? 'created';
          final resultMap = t['result'] as Map<String, dynamic>?;

          return TaskCard(
            status: status,
            inputText: t['inputText'] as String?,
            understanding: t['understanding'] as String?,
            progressMessage: status == 'executing' ? '正在执行…' : null,
            resultBody: resultMap?['body'] as String?,
            errorMessage: t['error'] as String?,
            confirmationMessage: status == 'waiting_confirm' ? (t['understanding'] as String? ?? '需要你的确认') : null,
            createdAt: t['createdAt'] as String? ?? DateTime.now().toIso8601String(),
            onTap: () => Navigator.pushNamed(context, '/task/${t['id']}'),
            onConfirm: status == 'waiting_confirm' ? () => _confirmTask(t['id']) : null,
            onCancel: status == 'waiting_confirm' ? () => _cancelTask(t['id']) : null,
            onRetry: status == 'failed' ? () => _retryTask(t['id']) : null,
          );
        },
      ),
    );
  }

  Widget _buildBottomArea(bool isDark) {
    return ChatInputBar(
      onSubmitText: _sendCommand,
      onRecordStart: () {},
      onRecordEnd: () => _sendCommand('[语音指令] 这是一条语音消息'),
      onRecordCancel: () {},
      onCamera: _onCamera,
      onPhotoLibrary: _onPhotoLibrary,
      onFile: _onFile,
    );
  }
}
