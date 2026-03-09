import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/session_entity.dart';

class NavDrawer extends StatelessWidget {
  final List<Session> sessions;
  final String? currentSessionId;
  final VoidCallback onNewSession;
  final ValueChanged<String> onSessionTap;
  final ValueChanged<String>? onSessionDelete;
  final VoidCallback? onSettings;
  final VoidCallback? onProfile;

  const NavDrawer({
    super.key,
    required this.sessions,
    this.currentSessionId,
    required this.onNewSession,
    required this.onSessionTap,
    this.onSessionDelete,
    this.onSettings,
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.background;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final separatorColor = isDark ? AppColors.separatorDark : AppColors.separator;

    final grouped = _groupByDate(sessions);

    return Drawer(
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(),
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text(
                    '知知',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textColor, letterSpacing: -0.2),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  onNewSession();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: secondaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '新建会话',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text('暂无会话', style: TextStyle(fontSize: 14, color: secondaryColor)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: grouped.length,
                      itemBuilder: (context, groupIndex) {
                        final group = grouped[groupIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                              child: Text(
                                group.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...group.sessions.map((session) => _SessionItem(
                              session: session,
                              isCurrent: session.id == currentSessionId,
                              isDark: isDark,
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              onTap: () {
                                Navigator.pop(context);
                                onSessionTap(session.id);
                              },
                              onDelete: onSessionDelete != null
                                  ? () => onSessionDelete!(session.id)
                                  : null,
                            )),
                          ],
                        );
                      },
                    ),
            ),

            Divider(height: 1, color: separatorColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onSettings?.call();
                },
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: secondaryColor),
                    const SizedBox(width: 8),
                    Text('设置', style: TextStyle(fontSize: 14, color: secondaryColor)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<Session> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(Duration(days: now.weekday - 1));

    final todayList = <Session>[];
    final yesterdayList = <Session>[];
    final thisWeekList = <Session>[];
    final olderList = <Session>[];

    for (final s in sessions) {
      final date = DateTime(s.updatedAt.year, s.updatedAt.month, s.updatedAt.day);
      if (date == today || date.isAfter(today)) {
        todayList.add(s);
      } else if (date == yesterday) {
        yesterdayList.add(s);
      } else if (date.isAfter(thisWeek)) {
        thisWeekList.add(s);
      } else {
        olderList.add(s);
      }
    }

    final groups = <_DateGroup>[];
    if (todayList.isNotEmpty) groups.add(_DateGroup('今天', todayList));
    if (yesterdayList.isNotEmpty) groups.add(_DateGroup('昨天', yesterdayList));
    if (thisWeekList.isNotEmpty) groups.add(_DateGroup('本周', thisWeekList));
    if (olderList.isNotEmpty) groups.add(_DateGroup('更早', olderList));
    return groups;
  }
}

class _DateGroup {
  final String label;
  final List<Session> sessions;
  _DateGroup(this.label, this.sessions);
}

class _SessionItem extends StatelessWidget {
  final Session session;
  final bool isCurrent;
  final bool isDark;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SessionItem({
    required this.session,
    required this.isCurrent,
    required this.isDark,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = isCurrent
        ? (isDark ? AppColors.surfaceSecondaryDark : AppColors.surfaceSecondary)
        : Colors.transparent;

    return Dismissible(
      key: ValueKey(session.id),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      confirmDismiss: (_) async {
        onDelete?.call();
        return false;
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: highlightColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            session.displayTitle,
            style: TextStyle(
              fontSize: 14,
              color: isCurrent ? textColor : secondaryColor,
              fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
