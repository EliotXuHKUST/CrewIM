import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class SceneCards extends StatelessWidget {
  final ValueChanged<String> onTap;

  const SceneCards({super.key, required this.onTap});

  static const _scenes = [
    _Scene(
      icon: Icons.checklist_rounded,
      title: '任务管理',
      desc: '整理待办、跟进进度',
      prompt: '帮我整理今天的待办事项',
    ),
    _Scene(
      icon: Icons.auto_awesome_rounded,
      title: '信息整理',
      desc: '汇总信息、提取要点',
      prompt: '帮我整理最近的重要信息',
    ),
    _Scene(
      icon: Icons.description_outlined,
      title: '文档生成',
      desc: '简报、邮件、会议纪要',
      prompt: '帮我生成一份工作简报',
    ),
    _Scene(
      icon: Icons.insights_rounded,
      title: '数据分析',
      desc: '分析数据、发现异常',
      prompt: '帮我分析最近的业务数据',
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
