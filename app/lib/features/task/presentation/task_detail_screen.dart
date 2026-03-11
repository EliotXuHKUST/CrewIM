import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../session/data/session_repository.dart';
import 'widgets/result_card.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _subTasks = [];
  bool _loading = true;
  Timer? _pollTimer;
  final _followUpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_task != null) {
        final status = _task!['status'] as String?;
        if (status == 'executing' || status == 'understanding' || status == 'created') {
          _loadDetail();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final result = await apiClient.getTaskDetail(widget.taskId);
      if (mounted) {
        setState(() {
          _task = result['task'] as Map<String, dynamic>?;
          _subTasks = (result['subTasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load detail from server failed: $e, trying local');
      if (_task == null) {
        final local = await SessionRepository().getTask(widget.taskId);
        if (local != null && mounted) {
          setState(() { _task = local; _loading = false; });
          return;
        }
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendFollowUp() async {
    final text = _followUpController.text.trim();
    if (text.isEmpty) return;
    _followUpController.clear();
    try {
      await apiClient.followUp(widget.taskId, text);
      await _loadDetail();
    } catch (e) {
      debugPrint('Follow up failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios, size: 20, color: secondaryColor),
                  ),
                  const Spacer(),
                  if (_task != null) _buildStatusChip(),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_task == null)
              Expanded(child: Center(child: Text('任务未找到', style: TextStyle(color: secondaryColor))))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _task!['inputText'] as String? ?? '',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textColor, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (_task!['understanding'] != null) ...[
                      Text('我理解的是', style: TextStyle(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 6),
                      Text(
                        _task!['understanding'] as String,
                        style: TextStyle(fontSize: 15, color: textColor, height: 1.6),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    if (_subTasks.isNotEmpty) ...[
                      Text('执行进展', style: TextStyle(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w400)),
                      const SizedBox(height: AppSpacing.md),
                      ..._subTasks.map((sub) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _statusIcon(sub['status'] as String? ?? 'pending'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sub['description'] as String? ?? '',
                                style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    if (_task!['result'] != null) ...[
                      Text('最终结果', style: TextStyle(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w400)),
                      const SizedBox(height: AppSpacing.sm),
                      _buildResult(isDark),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    if (_task!['error'] != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(isDark ? 25 : 12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                const Text('执行失败', style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _task!['error'] as String,
                              style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    if (_task!['status'] == 'waiting_confirm') ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await apiClient.cancelTask(widget.taskId);
                                _loadDetail();
                              },
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await apiClient.confirmTask(widget.taskId);
                                _loadDetail();
                              },
                              child: const Text('确认执行'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    if (_task!['status'] == 'failed') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await apiClient.retryTask(widget.taskId);
                            _loadDetail();
                          },
                          child: const Text('重试'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    TextButton.icon(
                      onPressed: () {
                        final sessionId = _task!['sessionId'] as String? ?? _task!['session_id'] as String?;
                        if (sessionId != null) {
                          Navigator.pushNamed(context, '/session/$sessionId');
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('查看对话上下文'),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),

            _buildFollowUpInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _task!['status'] as String? ?? '';
    final statusLabel = switch (status) {
      'created' => '已收到',
      'understanding' => '正在理解…',
      'executing' => '执行中…',
      'waiting_confirm' => '待确认',
      'completed' => '已完成',
      'failed' => '失败',
      'cancelled' => '已取消',
      _ => status,
    };
    final statusColor = switch (status) {
      'completed' => AppColors.success,
      'failed' => AppColors.error,
      'waiting_confirm' => AppColors.warning,
      'cancelled' => AppColors.textPlaceholder,
      _ => AppColors.accent,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _buildFollowUpInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.inputFillDark : AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _followUpController,
                onSubmitted: (_) => _sendFollowUp(),
                decoration: const InputDecoration(
                  hintText: '追问或补充…',
                  hintStyle: TextStyle(fontSize: 15, color: AppColors.textPlaceholder),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
            ),
            GestureDetector(
              onTap: _sendFollowUp,
              child: Icon(Icons.arrow_upward, size: 20, color: isDark ? AppColors.accentDark : AppColors.accent),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, size: 18, color: AppColors.success);
      case 'executing':
        return const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        );
      case 'failed':
        return const Icon(Icons.cancel, size: 18, color: AppColors.error);
      default:
        return Icon(Icons.circle_outlined, size: 18, color: AppColors.textPlaceholder);
    }
  }

  Widget _buildResult(bool isDark) {
    final result = _task!['result'];
    if (result is Map<String, dynamic>) {
      return ResultCard(
        title: result['title'] as String? ?? '结果',
        body: result['body'] as String?,
        isDark: isDark,
      );
    }
    return const SizedBox.shrink();
  }
}
