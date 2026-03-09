import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/session_repository.dart';
import '../domain/session_entity.dart';
import 'widgets/session_list_item.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final _repo = SessionRepository();
  List<Session> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _repo.getAllSessions();
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      debugPrint('Load sessions failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSession() async {
    final session = await _repo.createSession();
    if (mounted) {
      Navigator.pushNamed(context, '/session/${session.id}').then((_) => _loadSessions());
    }
  }

  Future<void> _deleteSession(Session session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除"${session.displayTitle}"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.deleteSession(session.id);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(textColor),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _sessions.isEmpty
                      ? _buildEmptyState()
                      : _buildSessionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      child: Row(
        children: [
          Text(
            '知知',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600,
              color: textColor, letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _createSession,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded, size: 20, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(20), shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 26, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          const Text(
            '点击右上角开始新会话',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('新建会话', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return SessionListItem(
            session: session,
            onTap: () {
              Navigator.pushNamed(context, '/session/${session.id}').then((_) => _loadSessions());
            },
            onDelete: () => _deleteSession(session),
          );
        },
      ),
    );
  }
}
