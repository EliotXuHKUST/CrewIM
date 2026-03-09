import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom input bar with 4 action buttons: camera, photo library, file, keyboard.
/// Each action is a direct input method — no typing required.
class InputActionBar extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onPhotoLibrary;
  final VoidCallback onFile;
  final VoidCallback onKeyboard;

  const InputActionBar({
    super.key,
    required this.onCamera,
    required this.onPhotoLibrary,
    required this.onFile,
    required this.onKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionIcon(
            icon: Icons.camera_alt_outlined,
            label: '拍照',
            color: iconColor,
            onTap: onCamera,
          ),
          _ActionIcon(
            icon: Icons.photo_library_outlined,
            label: '相册',
            color: iconColor,
            onTap: onPhotoLibrary,
          ),
          _ActionIcon(
            icon: Icons.folder_outlined,
            label: '文件',
            color: iconColor,
            onTap: onFile,
          ),
          _ActionIcon(
            icon: Icons.keyboard_outlined,
            label: '键盘',
            color: iconColor,
            onTap: onKeyboard,
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}
