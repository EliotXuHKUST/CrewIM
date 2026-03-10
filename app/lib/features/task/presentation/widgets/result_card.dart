import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/markdown_content.dart';

class ResultCard extends StatelessWidget {
  final String title;
  final String? body;
  final List<String>? items;
  final bool isDark;

  const ResultCard({
    super.key,
    required this.title,
    this.body,
    this.items,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final bgColor = isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            MarkdownContent(data: body!, textColor: textColor),
          ],
          if (items != null && items!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...items!.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${entry.key + 1}. ${entry.value}',
                style: TextStyle(fontSize: 15, height: 1.6, color: textColor),
              ),
            )),
          ],
        ],
      ),
    );
  }
}
