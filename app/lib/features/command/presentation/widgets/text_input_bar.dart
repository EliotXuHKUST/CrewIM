import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Text input bar per docs/design-guidelines.md Section 5.2.
class TextInputBar extends StatefulWidget {
  final ValueChanged<String>? onSubmit;
  final VoidCallback? onAttachImage;

  const TextInputBar({
    super.key,
    this.onSubmit,
    this.onAttachImage,
  });

  @override
  State<TextInputBar> createState() => _TextInputBarState();
}

class _TextInputBarState extends State<TextInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onAttachImage,
            child: const Icon(Icons.attach_file, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: '输入指令…',
                hintStyle: TextStyle(fontSize: 15, color: AppColors.textPlaceholder),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          GestureDetector(
            onTap: _hasText ? _submit : null,
            child: Icon(
              Icons.arrow_upward,
              size: 20,
              color: _hasText ? AppColors.accent : AppColors.textPlaceholder,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
