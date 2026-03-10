import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class MarkdownContent extends StatelessWidget {
  final String data;
  final Color? textColor;
  final double fontSize;
  final bool selectable;

  const MarkdownContent({
    super.key,
    required this.data,
    this.textColor,
    this.fontSize = 15,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textPrimary;

    final styleSheet = MarkdownStyleSheet(
      p: TextStyle(fontSize: fontSize, color: color, height: 1.6),
      h1: TextStyle(fontSize: fontSize + 6, fontWeight: FontWeight.w600, color: color, height: 1.4),
      h2: TextStyle(fontSize: fontSize + 4, fontWeight: FontWeight.w600, color: color, height: 1.4),
      h3: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.w600, color: color, height: 1.4),
      h4: TextStyle(fontSize: fontSize + 1, fontWeight: FontWeight.w500, color: color, height: 1.4),
      strong: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color),
      em: TextStyle(fontSize: fontSize, fontStyle: FontStyle.italic, color: color),
      code: TextStyle(
        fontSize: fontSize - 1,
        color: color,
        backgroundColor: AppColors.surfaceSecondary,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: TextStyle(fontSize: fontSize, color: AppColors.textSecondary, height: 1.6),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.separator, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      listBullet: TextStyle(fontSize: fontSize, color: color),
      tableHead: TextStyle(fontSize: fontSize - 1, fontWeight: FontWeight.w600, color: color),
      tableBody: TextStyle(fontSize: fontSize - 1, color: color),
      tableBorder: TableBorder.all(color: AppColors.separator, width: 0.5),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      pPadding: const EdgeInsets.only(bottom: 4),
      h1Padding: const EdgeInsets.only(bottom: 8, top: 4),
      h2Padding: const EdgeInsets.only(bottom: 6, top: 4),
      h3Padding: const EdgeInsets.only(bottom: 4, top: 2),
    );

    if (selectable) {
      return MarkdownBody(
        data: data,
        styleSheet: styleSheet,
        selectable: true,
        onTapLink: _onTapLink,
        shrinkWrap: true,
        softLineBreak: true,
      );
    }

    return MarkdownBody(
      data: data,
      styleSheet: styleSheet,
      onTapLink: _onTapLink,
      shrinkWrap: true,
      softLineBreak: true,
    );
  }

  void _onTapLink(String text, String? href, String title) {
    if (href != null) {
      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
    }
  }
}
