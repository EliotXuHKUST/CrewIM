import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/message_entity.dart';
import 'task_cards.dart';

class ChatMessageBubble extends StatelessWidget {
  final Message message;
  final bool showTimestamp;
  final TaskAction? onTaskAction;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = false,
    this.onTaskAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (showTimestamp) _buildTimestamp(isDark),
        if (message.isUser)
          _buildUserBubble(isDark)
        else if (message.isTaskCard)
          TaskMessageCard(message: message, onAction: onTaskAction)
        else
          _buildAssistantBubble(isDark),
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
}
