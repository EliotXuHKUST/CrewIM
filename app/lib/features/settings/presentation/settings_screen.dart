import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/storage/local_database.dart';
import 'account_edit_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _phone;
  String _gatewayUrl = '';
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _phone = await AuthStorage.getPhone();

    try {
      final profile = await apiClient.getProfile();
      final p = profile['profile'] as Map<String, dynamic>? ?? {};
      _gatewayUrl = p['openclaw_gateway_url'] as String? ?? '';
    } catch (_) {}

    try {
      final result = await apiClient.getAccounts();
      final list = result['accounts'] as List?;
      if (list != null) {
        _accounts = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveGatewayUrl(String url) async {
    try {
      await apiClient.updateProfile({'profile': {'openclaw_gateway_url': url}});
      setState(() => _gatewayUrl = url);
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthStorage.clear();
      apiClient.clearToken();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  Future<void> _deleteUserAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
          '注销后所有数据将被永久删除，包括会话记录、任务历史、绑定账号等。此操作不可撤销。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认注销', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('最终确认'),
        content: const Text('真的要永久删除账号和所有数据吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('我再想想')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('永久删除', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (doubleConfirm != true || !mounted) return;

    try {
      await apiClient.deleteMyAccount();
      await AuthStorage.clear();
      await LocalDatabase.close();
      apiClient.clearToken();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注销失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteThirdPartyAccount(String id) async {
    try {
      await apiClient.deleteAccount(id);
      _accounts.removeWhere((a) => a['id'] == id);
      setState(() {});
    } catch (_) {}
  }

  void _openAddAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AccountEditScreen()),
    );
    if (result == true) _load();
  }

  void _openEditAccount(Map<String, dynamic> account) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AccountEditScreen(account: account)),
    );
    if (result == true) _load();
  }

  void _openFeedback() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('意见反馈'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '请描述你遇到的问题或建议…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx);
                  try {
                    await apiClient.sendFeedback(text);
                  } catch (_) {}
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('感谢你的反馈！'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('提交'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final cardColor = isDark ? AppColors.cardDark : AppColors.card;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios, size: 20, color: secondaryColor),
                  ),
                  const SizedBox(width: 4),
                  Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textColor)),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    _SectionHeader(title: '账号', color: secondaryColor),
                    _Card(
                      color: cardColor,
                      children: [
                        _Row(
                          label: '手机号',
                          value: _phone ?? '-',
                          textColor: textColor,
                          valueColor: secondaryColor,
                        ),
                        Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
                        _TapRow(
                          label: '退出登录',
                          labelColor: AppColors.textSecondary,
                          onTap: _logout,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: 'AI 服务', color: secondaryColor),
                    _Card(
                      color: cardColor,
                      children: [
                        _EditableRow(
                          label: 'OpenClaw Gateway',
                          value: _gatewayUrl,
                          hint: 'ws://your-gateway:18789',
                          textColor: textColor,
                          secondaryColor: secondaryColor,
                          onSave: _saveGatewayUrl,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _SectionHeader(title: '已绑定账号', color: secondaryColor),
                        const Spacer(),
                        GestureDetector(
                          onTap: _openAddAccount,
                          child: Icon(Icons.add_circle_outline, size: 20, color: secondaryColor),
                        ),
                      ],
                    ),
                    if (_accounts.isEmpty)
                      _Card(
                        color: cardColor,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('暂未绑定任何账号', style: TextStyle(fontSize: 14, color: secondaryColor)),
                            ),
                          ),
                        ],
                      )
                    else
                      _Card(
                        color: cardColor,
                        children: [
                          for (var i = 0; i < _accounts.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
                            _AccountRow(
                              account: _accounts[i],
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              onTap: () => _openEditAccount(_accounts[i]),
                              onDelete: () => _deleteThirdPartyAccount(_accounts[i]['id'] as String),
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: '支持', color: secondaryColor),
                    _Card(
                      color: cardColor,
                      children: [
                        _TapRow(
                          label: '意见反馈',
                          labelColor: textColor,
                          trailing: true,
                          onTap: _openFeedback,
                        ),
                        Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
                        _TapRow(
                          label: '隐私政策',
                          labelColor: textColor,
                          trailing: true,
                          onTap: () {
                            // Opens privacy policy - replace URL with real one
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('隐私政策页面开发中'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
                        _TapRow(
                          label: '用户协议',
                          labelColor: textColor,
                          trailing: true,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('用户协议页面开发中'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: '关于', color: secondaryColor),
                    _Card(
                      color: cardColor,
                      children: [
                        _Row(label: '版本', value: '1.0.0', textColor: textColor, valueColor: secondaryColor),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _Card(
                      color: cardColor,
                      children: [
                        _TapRow(
                          label: '注销账号',
                          labelColor: AppColors.error,
                          onTap: _deleteUserAccount,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

class _Card extends StatelessWidget {
  final Color color;
  final List<Widget> children;
  const _Card({required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color valueColor;
  const _Row({required this.label, required this.value, required this.textColor, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: textColor)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 15, color: valueColor)),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String label;
  final Color labelColor;
  final bool trailing;
  final VoidCallback onTap;
  const _TapRow({required this.label, required this.labelColor, this.trailing = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, color: labelColor)),
            ),
            if (trailing)
              Icon(Icons.chevron_right, size: 18, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EditableRow extends StatefulWidget {
  final String label;
  final String value;
  final String hint;
  final Color textColor;
  final Color secondaryColor;
  final ValueChanged<String> onSave;

  const _EditableRow({
    required this.label,
    required this.value,
    required this.hint,
    required this.textColor,
    required this.secondaryColor,
    required this.onSave,
  });

  @override
  State<_EditableRow> createState() => _EditableRowState();
}

class _EditableRowState extends State<_EditableRow> {
  bool _editing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: TextStyle(fontSize: 13, color: widget.secondaryColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                filled: true,
              ),
              style: TextStyle(fontSize: 14, color: widget.textColor),
              onSubmitted: (v) {
                widget.onSave(v.trim());
                setState(() => _editing = false);
              },
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: TextStyle(fontSize: 15, color: widget.textColor)),
                  if (widget.value.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(widget.value, style: TextStyle(fontSize: 13, color: widget.secondaryColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: widget.secondaryColor),
          ],
        ),
      ),
    );
  }
}

String _platformLabel(String platform) => switch (platform) {
  'email' => '邮箱',
  'wechat_mp' => '微信公众号',
  'xiaohongshu' => '小红书',
  _ => platform,
};

IconData _platformIcon(String platform) => switch (platform) {
  'email' => Icons.email_outlined,
  'wechat_mp' => Icons.chat_outlined,
  'xiaohongshu' => Icons.auto_stories_outlined,
  _ => Icons.link,
};

class _AccountRow extends StatelessWidget {
  final Map<String, dynamic> account;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AccountRow({
    required this.account,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final platform = account['platform'] as String? ?? '';
    final displayName = account['display_name'] as String? ?? '';

    return Dismissible(
      key: ValueKey(account['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(_platformIcon(platform), size: 20, color: secondaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_platformLabel(platform), style: TextStyle(fontSize: 15, color: textColor)),
                    if (displayName.isNotEmpty)
                      Text(displayName, style: TextStyle(fontSize: 12, color: secondaryColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: secondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
