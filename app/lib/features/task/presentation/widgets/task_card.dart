import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class TaskCard extends StatelessWidget {
  final String status;
  final String? inputText;
  final String? understanding;
  final String? progressMessage;
  final String? resultBody;
  final String? errorMessage;
  final String? confirmationMessage;
  final String createdAt;
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const TaskCard({
    super.key,
    required this.status,
    this.inputText,
    this.understanding,
    this.progressMessage,
    this.resultBody,
    this.errorMessage,
    this.confirmationMessage,
    required this.createdAt,
    this.onTap,
    this.onConfirm,
    this.onCancel,
    this.onRetry,
  });

  Color get _statusColor => switch (status) {
    'created' || 'understanding' || 'executing' => AppColors.accent,
    'waiting_confirm' => AppColors.warning,
    'completed' => AppColors.success,
    'failed' => AppColors.error,
    _ => AppColors.textPlaceholder,
  };

  String get _statusLabel => switch (status) {
    'created' => '已收到',
    'understanding' => '正在理解',
    'executing' => '执行中',
    'waiting_confirm' => '待确认',
    'completed' => '已完成',
    'failed' => '失败',
    'cancelled' => '已取消',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: status == 'waiting_confirm'
              ? Border.all(color: AppColors.warning.withAlpha(40), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 10),
            _buildMainContent(isDark),
            if (status == 'waiting_confirm') ...[
              const SizedBox(height: AppSpacing.lg),
              _buildConfirmationButtons(),
            ],
            if (status == 'failed' && onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildRetryButton(isDark),
            ],
            if (status == 'completed' && onTap != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildViewDetail(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        _StatusDot(color: _statusColor, animated: status == 'executing' || status == 'understanding'),
        const SizedBox(width: 6),
        Text(
          _statusLabel,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: _statusColor),
        ),
        const Spacer(),
        Text(
          _formatTime(createdAt),
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMainContent(bool isDark) {
    final displayText = understanding ?? inputText ?? '';
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayText.isNotEmpty)
          Text(displayText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor, height: 1.4)),
        if (status == 'executing' && progressMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(progressMessage!, style: TextStyle(fontSize: 13, color: secondaryColor)),
              ),
            ],
          ),
        ],
        if (status == 'completed' && resultBody != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              resultBody!,
              style: TextStyle(fontSize: 14, color: textColor, height: 1.7),
            ),
          ),
        ],
        if (status == 'failed' && errorMessage != null) ...[
          const SizedBox(height: 6),
          Text(errorMessage!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
        ],
        if (status == 'waiting_confirm' && confirmationMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            confirmationMessage!,
            style: TextStyle(fontSize: 14, color: secondaryColor, height: 1.6),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmationButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onConfirm,
              child: const Text('确认'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton(bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppColors.accentDark : AppColors.accent,
            side: BorderSide(color: isDark ? AppColors.accentDark : AppColors.accent),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('重试'),
        ),
      ),
    );
  }

  Widget _buildViewDetail(bool isDark) {
    final accentColor = isDark ? AppColors.accentDark : AppColors.accent;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('查看详情', style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w400)),
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        return '昨天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool animated;

  const _StatusDot({required this.color, this.animated = false});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.animated) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animated) {
      return Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: widget.color.withAlpha((255 * (0.4 + 0.6 * _controller.value)).toInt()),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
