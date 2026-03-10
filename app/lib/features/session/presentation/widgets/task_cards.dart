import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/message_entity.dart';

typedef TaskAction = void Function(String taskId, String action, {String? text});

class TaskMessageCard extends StatelessWidget {
  final Message message;
  final TaskAction? onAction;

  const TaskMessageCard({
    super.key,
    required this.message,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 40, top: 4, bottom: 4),
      child: switch (message.type) {
        MessageType.taskUnderstanding => _UnderstandingCard(message: message, onAction: onAction),
        MessageType.taskProgress => _ProgressCard(message: message),
        MessageType.taskWaitingConfirm => _ConfirmCard(message: message, onAction: onAction),
        MessageType.taskCompleted => _ResultCard(message: message, onAction: onAction),
        MessageType.taskFailed => _ErrorCard(message: message, onAction: onAction),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _UnderstandingCard extends StatelessWidget {
  final Message message;
  final TaskAction? onAction;

  const _UnderstandingCard({required this.message, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.cardDark : AppColors.card;
    final borderColor = isDark ? AppColors.separatorDark : AppColors.separator;

    final understanding = message.metadata?['understanding'] as String? ?? message.content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                '我理解的是',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            understanding,
            style: TextStyle(fontSize: 15, color: textColor, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final Message message;

  const _ProgressCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.cardDark : AppColors.card;
    final borderColor = isDark ? AppColors.separatorDark : AppColors.separator;

    final step = message.metadata?['step'] as String? ?? message.content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '执行中',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor),
                ),
                const SizedBox(height: 2),
                Text(
                  step,
                  style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final Message message;
  final TaskAction? onAction;

  const _ConfirmCard({required this.message, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.separatorDark : AppColors.separator;

    final understanding = message.metadata?['understanding'] as String? ?? '';
    final confirmMessage = message.metadata?['confirmMessage'] as String? ?? message.content;
    final taskId = message.taskId;
    final confirmed = message.metadata?['confirmed'] as bool? ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1A12) : const Color(0xFFFEFCE8),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: confirmed ? borderColor : AppColors.warning.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confirmed ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 15,
                color: confirmed ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                confirmed ? '已确认' : '需要你拍板',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: confirmed ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (understanding.isNotEmpty) ...[
            Text(
              understanding,
              style: TextStyle(fontSize: 15, color: textColor, height: 1.5),
            ),
            const SizedBox(height: 4),
          ],
          if (confirmMessage.isNotEmpty && confirmMessage != understanding)
            Text(
              confirmMessage,
              style: TextStyle(fontSize: 13, color: secondaryColor, height: 1.4),
            ),
          if (!confirmed && taskId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: '取消',
                    outlined: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAction?.call(taskId, 'cancel');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: '确认执行',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAction?.call(taskId, 'confirm');
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Message message;
  final TaskAction? onAction;

  const _ResultCard({required this.message, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final dividerColor = isDark ? AppColors.separatorDark : AppColors.separator;

    final resultTitle = message.metadata?['resultTitle'] as String? ?? '执行结果';
    final resultBody = message.metadata?['resultBody'] as String? ?? message.content;
    final taskId = message.taskId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A12) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 15, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  resultTitle,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resultBody,
            style: TextStyle(fontSize: 15, color: textColor, height: 1.6),
          ),
          if (taskId != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _SmallAction(
                  icon: Icons.content_copy_rounded,
                  label: '复制',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: resultBody));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _SmallAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '继续处理',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAction?.call(taskId, 'follow_up');
                  },
                ),
                _SmallAction(
                  icon: Icons.description_outlined,
                  label: '转文档',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAction?.call(taskId, 'to_doc', text: resultBody);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Message message;
  final TaskAction? onAction;

  const _ErrorCard({required this.message, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    final error = message.metadata?['error'] as String? ?? message.content;
    final taskId = message.taskId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A0F0F) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
              const SizedBox(width: 6),
              Text(
                '执行失败',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
          ),
          if (taskId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionButton(
                  label: '重试',
                  compact: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAction?.call(taskId, 'retry');
                  },
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: '补充信息',
                  outlined: true,
                  compact: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAction?.call(taskId, 'follow_up');
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline follow-up input that appears when user taps "补充一句" on an executing task.
class FollowUpInput extends StatefulWidget {
  final String taskId;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  const FollowUpInput({
    super.key,
    required this.taskId,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<FollowUpInput> createState() => _FollowUpInputState();
}

class _FollowUpInputState extends State<FollowUpInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.separatorDark : AppColors.separator;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '补充一句…',
                hintStyle: TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) widget.onSubmit(text.trim());
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final text = _controller.text.trim();
              if (text.isNotEmpty) {
                widget.onSubmit(text);
              } else {
                widget.onCancel();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
              child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable small components ──

class _ActionButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final bool compact;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    this.outlined = false,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 0,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: outlined
              ? Colors.transparent
              : (isDark ? AppColors.accentDark : AppColors.accent),
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: outlined
              ? Border.all(color: isDark ? AppColors.separatorDark : AppColors.buttonOutline)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: outlined
                  ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? AppColors.separatorDark : AppColors.separator,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
