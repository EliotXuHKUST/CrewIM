import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_manager.dart';
import '../../command/presentation/widgets/chat_input_bar.dart';
import '../../session/data/session_repository.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final _repo = SessionRepository();
  List<Map<String, dynamic>> _highlights = [];
  int _restCount = 0;
  String _restSummary = '';
  int _todayCompleted = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SocketManager.instance.connect();
    SocketManager.instance.addListener(null, _onWsEvent);
    _loadBriefing();
  }

  @override
  void dispose() {
    SocketManager.instance.removeListener(null, _onWsEvent);
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'task_completed' || type == 'task_failed' ||
        type == 'task_waiting_confirm' || type == 'task_understanding') {
      _loadBriefing();
    }
  }

  Future<void> _loadBriefing() async {
    try {
      final result = await apiClient.getBriefing();
      if (mounted) {
        setState(() {
          _highlights = (result['highlights'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _restCount = result['rest_count'] as int? ?? 0;
          _restSummary = result['rest_summary'] as String? ?? '';
          _todayCompleted = result['today_completed'] as int? ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 18) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  Future<void> _sendText(String text) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commandSent),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    final session = await _repo.createSession();
    await _repo.addUserMessage(session.id, text);
    try {
      await apiClient.sendCommand(text, sessionId: session.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
    _loadBriefing();
  }

  Future<void> _sendMedia({String? audioPath, List<String>? imagePaths}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.uploading),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    final session = await _repo.createSession();
    try {
      await apiClient.sendCommandWithMedia(
        audioPath: audioPath,
        imagePaths: imagePaths,
        sessionId: session.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
    _loadBriefing();
  }

  Future<void> _handleAction(String taskId, String action) async {
    try {
      switch (action) {
        case 'confirm':
          await apiClient.confirmTask(taskId);
        case 'cancel':
          await apiClient.cancelTask(taskId);
        case 'retry':
          await apiClient.retryTask(taskId);
        case 'resume':
          await apiClient.resumeTask(taskId);
        case 'pause':
          await apiClient.pauseTask(taskId);
        case 'detail':
          if (mounted) Navigator.pushNamed(context, '/task/$taskId');
          return;
      }
      _loadBriefing();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(l10n),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : RefreshIndicator(
                      onRefresh: _loadBriefing,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          const SizedBox(height: 20),
                          _buildGreeting(l10n),
                          const SizedBox(height: 24),
                          if (_highlights.isNotEmpty)
                            ..._highlights.map((h) => _buildHighlightCard(h, l10n))
                          else
                            _buildEmptyState(l10n),
                          if (_restCount > 0) ...[
                            const SizedBox(height: 16),
                            _buildRestSummary(l10n),
                          ],
                          if (_todayCompleted > 0) ...[
                            const SizedBox(height: 12),
                            _buildTodayCompleted(l10n),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
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

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            l10n.appName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/all-tasks'),
            icon: const Icon(Icons.list_alt_rounded, size: 22, color: AppColors.textSecondary),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined, size: 22, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(AppLocalizations l10n) {
    final count = _highlights.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3),
        ),
        const SizedBox(height: 4),
        Text(
          count > 0 ? l10n.highlightCount(count) : l10n.allGood,
          style: TextStyle(
            fontSize: 15,
            color: count > 0 ? AppColors.warning : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard(Map<String, dynamic> h, AppLocalizations l10n) {
    final task = h['task'] as Map<String, dynamic>? ?? {};
    final taskId = task['id'] as String? ?? '';
    final understanding = task['understanding'] as String? ?? task['inputText'] as String? ?? '';
    final status = task['status'] as String? ?? '';
    final reasonKey = h['reason'] as String? ?? '';
    final reason = switch (reasonKey) {
      'needs_decision' => l10n.needsDecision,
      'failed' => l10n.failed,
      'in_progress' => l10n.inProgress,
      'taking_long' => l10n.takingLong,
      'paused' => l10n.paused,
      _ => reasonKey,
    };
    final actions = (h['actions'] as List?)?.cast<String>() ?? ['detail'];

    final statusColor = switch (status) {
      'waiting_confirm' => AppColors.warning,
      'failed' => AppColors.error,
      'paused' => AppColors.textPlaceholder,
      _ => AppColors.accent,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/task/$taskId').then((_) => _loadBriefing()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.separator, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                understanding,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: actions.map((a) => _buildActionChip(taskId, a, l10n)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(String taskId, String action, AppLocalizations l10n) {
    final label = switch (action) {
      'confirm' => l10n.confirm,
      'cancel' => l10n.cancel,
      'retry' => l10n.retry,
      'resume' => l10n.resume,
      'pause' => l10n.pause,
      'detail' => l10n.detail,
      _ => action,
    };

    final isPrimary = action == 'confirm' || action == 'resume' || action == 'retry';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleAction(taskId, action);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isPrimary ? null : Border.all(color: AppColors.buttonOutline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isPrimary ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    if (_todayCompleted > 0 || _restCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 24, color: AppColors.success),
            ),
            const SizedBox(height: 12),
            Text(l10n.allGood, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final prompts = [
      (Icons.description_outlined, l10n.scene1Title, l10n.scene1Desc, '帮我写一份本周的工作简报'),
      (Icons.checklist_rounded, l10n.scene2Title, l10n.scene2Desc, '帮我列一个今天的待办清单'),
      (Icons.auto_awesome_rounded, l10n.scene3Title, l10n.scene3Desc, '帮我分析一下团队最近的问题'),
      (Icons.email_outlined, l10n.scene4Title, l10n.scene4Desc, '帮我给团队写一封会议通知邮件'),
    ];

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.tryFirstCommand,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.tapSceneToStart,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ...prompts.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _sendText(p.$4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(p.$1, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        Text(p.$3, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textPlaceholder),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildRestSummary(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/all-tasks'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _restSummary.isNotEmpty ? _restSummary : l10n.restSummary(_restCount),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Text(
            l10n.viewAll,
            style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildTodayCompleted(AppLocalizations l10n) {
    return Text(
      l10n.todayCompleted(_todayCompleted),
      style: const TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
    );
  }
}
