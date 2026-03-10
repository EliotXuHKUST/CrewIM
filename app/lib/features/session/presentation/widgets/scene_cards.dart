import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class SceneCards extends StatelessWidget {
  final ValueChanged<String> onTap;

  const SceneCards({super.key, required this.onTap});

  static const _scenes = [
    _Scene(
      icon: Icons.description_outlined,
      title: '写个方案',
      desc: '简报、邮件草稿、会议纪要',
      prompt: '帮我写一份本周的工作简报，重点包括完成的事项和下周计划',
    ),
    _Scene(
      icon: Icons.checklist_rounded,
      title: '列个清单',
      desc: '把事情拆解成行动项',
      prompt: '帮我把这些事整理成一个待办清单：招聘进度跟进、Q2预算初稿、客户回访',
    ),
    _Scene(
      icon: Icons.auto_awesome_rounded,
      title: '帮我想想',
      desc: '分析问题、给出建议',
      prompt: '团队最近士气不太好，帮我想想可能的原因和改善方案',
    ),
    _Scene(
      icon: Icons.email_outlined,
      title: '发封邮件',
      desc: '起草并发送邮件',
      prompt: '帮我给团队写一封邮件，通知下周三下午2点开季度复盘会',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 48),
            Text(
              '有什么可以帮你？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textColor, letterSpacing: -0.2),
            ),
            const SizedBox(height: 6),
            Text(
              '选择一个场景或直接输入指令',
              style: TextStyle(fontSize: 14, color: secondaryColor),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: _scenes.map((s) => _SceneCard(
                scene: s,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(s.prompt);
                },
              )).toList(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Scene {
  final IconData icon;
  final String title;
  final String desc;
  final String prompt;

  const _Scene({
    required this.icon,
    required this.title,
    required this.desc,
    required this.prompt,
  });
}

class _SceneCard extends StatelessWidget {
  final _Scene scene;
  final bool isDark;
  final VoidCallback onTap;

  const _SceneCard({
    required this.scene,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final descColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final iconColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final iconBg = isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.separatorDark : AppColors.separator,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(scene.icon, size: 18, color: iconColor),
            ),
            const Spacer(),
            Text(
              scene.title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              scene.desc,
              style: TextStyle(fontSize: 12, color: descColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
