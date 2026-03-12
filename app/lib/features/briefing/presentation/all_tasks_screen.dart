import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';

class AllTasksScreen extends StatefulWidget {
  const AllTasksScreen({super.key});

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await apiClient.getTasks(limit: 50);
      final list = (result['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _tasks = list; _loading = false; _searching = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _load();
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await apiClient.searchTasks(query.trim());
      final list = (result['tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _tasks = list; _loading = false; _searching = true; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final pending = _tasks.where((t) => t['status'] == 'waiting_confirm').toList();
    final executing = _tasks.where((t) =>
      t['status'] == 'executing' || t['status'] == 'understanding' ||
      t['status'] == 'created' || t['status'] == 'paused').toList();
    final completed = _tasks.where((t) => t['status'] == 'completed').toList();
    final failed = _tasks.where((t) => t['status'] == 'failed').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  Text(l10n.allTasks, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  hintStyle: const TextStyle(color: AppColors.textPlaceholder, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textPlaceholder),
                  suffixIcon: _searching ? IconButton(
                    onPressed: () { _searchController.clear(); _load(); },
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ) : null,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (pending.isNotEmpty) _buildSection(l10n.pendingConfirm, pending, AppColors.warning),
                          if (failed.isNotEmpty) _buildSection(l10n.taskFailed, failed, AppColors.error),
                          if (executing.isNotEmpty) _buildSection(l10n.executingTasks, executing, AppColors.accent),
                          if (completed.isNotEmpty) _buildSection(l10n.completedTasks, completed, AppColors.success),
                          if (_tasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Center(child: Text(l10n.noTasks, style: const TextStyle(color: AppColors.textSecondary))),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> tasks, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 6),
            Text('${tasks.length}', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.6))),
          ],
        ),
        const SizedBox(height: 8),
        ...tasks.map((t) => _buildTaskRow(t)),
      ],
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task) {
    final id = task['id'] as String? ?? '';
    final understanding = task['understanding'] as String?;
    final inputText = task['inputText'] as String?;
    final label = understanding ?? inputText ?? '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/task/$id').then((_) => _load()),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
