import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/message_entity.dart';

class ChatMessageBubble extends StatelessWidget {
  final Message message;
  final bool showTimestamp;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (showTimestamp) _buildTimestamp(isDark),
        message.isUser ? _buildUserBubble(isDark) : _buildAssistantBubble(isDark),
      ],
    );
  }

  Widget _buildTimestamp(bool isDark) {
    final time = message.createdAt.toLocal();
    final label = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textPlaceholder,
        ),
      ),
    );
  }

  Widget _buildUserBubble(bool isDark) {
    final bgColor = isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(fontSize: 15, color: textColor, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(bool isDark) {
    final bgColor = isDark ? AppColors.cardDark : AppColors.card;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor = isDark ? AppColors.separatorDark : AppColors.separator;

    final content = message.content;
    final isStatus = content.startsWith('✓') || content.startsWith('✗') || content.startsWith('⚠') || content.contains('执行中');

    Color? statusColor;
    if (content.startsWith('✓')) statusColor = AppColors.success;
    if (content.startsWith('✗')) statusColor = AppColors.error;
    if (content.startsWith('⚠')) statusColor = AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 56, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: isStatus && statusColor != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            content,
                            style: TextStyle(fontSize: 15, color: textColor, height: 1.5),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      content,
                      style: TextStyle(fontSize: 15, color: textColor, height: 1.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
