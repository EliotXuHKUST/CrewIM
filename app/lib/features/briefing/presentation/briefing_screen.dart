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
    final session = await _repo.createSession();
    await _repo.addUserMessage(session.id, text);
    try {
      await apiClient.sendCommand(text, sessionId: session.id);
    } catch (_) {}
    _loadBriefing();
  }

  Future<void> _sendMedia({String? audioPath, List<String>? imagePaths}) async {
    final session = await _repo.createSession();
    try {
      await apiClient.sendCommandWithMedia(
        audioPath: audioPath,
        imagePaths: imagePaths,
        sessionId: session.id,
      );
    } catch (_) {}
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
                            _buildAllGood(l10n),
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
    final reason = h['reason'] as String? ?? '';
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

  Widget _buildAllGood(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 28, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.allGood,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
