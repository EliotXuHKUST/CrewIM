import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Left drawer showing conversation/task history grouped by date.
class HistoryDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final void Function(String taskId) onTaskTap;

  const HistoryDrawer({
    super.key,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.background;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    final grouped = _groupByDate(tasks);

    return Drawer(
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Text(
                '历史记录',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text('暂无历史', style: TextStyle(fontSize: 14, color: secondaryColor)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final group = grouped[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: Text(
                                group.label,
                                style: TextStyle(fontSize: 11, color: secondaryColor, fontWeight: FontWeight.w500),
                              ),
                            ),
                            ...group.tasks.map((t) => _HistoryItem(
                              task: t,
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              onTap: () {
                                Navigator.pop(context);
                                onTaskTap(t['id'] as String);
                              },
                            )),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<Map<String, dynamic>> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(Duration(days: now.weekday - 1));

    final todayTasks = <Map<String, dynamic>>[];
    final yesterdayTasks = <Map<String, dynamic>>[];
    final thisWeekTasks = <Map<String, dynamic>>[];
    final olderTasks = <Map<String, dynamic>>[];

    for (final t in tasks) {
      final createdStr = t['createdAt'] as String? ?? '';
      DateTime created;
      try {
        created = DateTime.parse(createdStr).toLocal();
      } catch (_) {
        continue;
      }
      final date = DateTime(created.year, created.month, created.day);

      if (date == today) {
        todayTasks.add(t);
      } else if (date == yesterday) {
        yesterdayTasks.add(t);
      } else if (date.isAfter(thisWeek)) {
        thisWeekTasks.add(t);
      } else {
        olderTasks.add(t);
      }
    }

    final groups = <_DateGroup>[];
    if (todayTasks.isNotEmpty) groups.add(_DateGroup('今天', todayTasks));
    if (yesterdayTasks.isNotEmpty) groups.add(_DateGroup('昨天', yesterdayTasks));
    if (thisWeekTasks.isNotEmpty) groups.add(_DateGroup('本周', thisWeekTasks));
    if (olderTasks.isNotEmpty) groups.add(_DateGroup('更早', olderTasks));
    return groups;
  }
}

class _DateGroup {
  final String label;
  final List<Map<String, dynamic>> tasks;
  _DateGroup(this.label, this.tasks);
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _HistoryItem({
    required this.task,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? '';
    final text = task['understanding'] as String? ?? task['inputText'] as String? ?? '';
    final statusColor = switch (status) {
      'completed' => AppColors.success,
      'failed' => AppColors.error,
      'executing' || 'understanding' => AppColors.accent,
      'waiting_confirm' => AppColors.warning,
      _ => AppColors.textPlaceholder,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: textColor, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
