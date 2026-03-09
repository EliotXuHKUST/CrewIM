import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';

class AccountEditScreen extends StatefulWidget {
  final Map<String, dynamic>? account;
  const AccountEditScreen({super.key, this.account});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  bool get _isEditing => widget.account != null;

  String _selectedPlatform = 'email';
  final _displayNameController = TextEditingController();
  final _fields = <String, TextEditingController>{};
  bool _saving = false;

  static const _platformConfigs = {
    'email': [
      _FieldConfig('smtp_host', 'SMTP 服务器', 'smtp.example.com'),
      _FieldConfig('smtp_port', '端口', '465'),
      _FieldConfig('email', '邮箱地址', 'you@example.com'),
      _FieldConfig('password', '授权码', '授权码或密码', obscure: true),
    ],
    'wechat_mp': [
      _FieldConfig('app_id', 'AppID', '公众号 AppID'),
      _FieldConfig('app_secret', 'AppSecret', '公众号 AppSecret', obscure: true),
    ],
    'xiaohongshu': [
      _FieldConfig('account_name', '账号名', '小红书昵称'),
      _FieldConfig('cookie', 'Cookie / Session', '登录后的 Cookie', obscure: true),
    ],
  };

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedPlatform = widget.account!['platform'] as String? ?? 'email';
      _displayNameController.text = widget.account!['display_name'] as String? ?? '';
    }
    _initFields();
  }

  void _initFields() {
    _fields.clear();
    final configs = _platformConfigs[_selectedPlatform] ?? [];
    for (final c in configs) {
      _fields[c.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final credentials = <String, dynamic>{};
      for (final entry in _fields.entries) {
        final v = entry.value.text.trim();
        if (v.isNotEmpty) credentials[entry.key] = v;
      }

      if (_isEditing) {
        await apiClient.updateAccount(
          id: widget.account!['id'] as String,
          displayName: _displayNameController.text.trim(),
          credentials: credentials.isNotEmpty ? credentials : null,
        );
      } else {
        await apiClient.createAccount(
          platform: _selectedPlatform,
          displayName: _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim(),
          credentials: credentials,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final fillColor = isDark ? AppColors.inputFillDark : AppColors.inputFill;
    final configs = _platformConfigs[_selectedPlatform] ?? [];

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                  Text(
                    _isEditing ? '编辑账号' : '添加账号',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: textColor),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? AppColors.accentDark : AppColors.accent)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  if (!_isEditing) ...[
                    Text('平台', style: TextStyle(fontSize: 13, color: secondaryColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _platformConfigs.keys.map((p) {
                        final selected = p == _selectedPlatform;
                        return ChoiceChip(
                          label: Text(_platformLabel(p)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedPlatform = p;
                              _initFields();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text('显示名称', style: TextStyle(fontSize: 13, color: secondaryColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      hintText: '可选，方便识别',
                      filled: true,
                      fillColor: fillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: TextStyle(fontSize: 15, color: textColor),
                  ),

                  const SizedBox(height: 20),
                  if (configs.isNotEmpty)
                    Text(
                      _isEditing ? '更新凭据（留空则不修改）' : '凭据信息',
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),

                  for (final c in configs) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fields[c.key],
                      obscureText: c.obscure,
                      decoration: InputDecoration(
                        labelText: c.label,
                        hintText: c.hint,
                        filled: true,
                        fillColor: fillColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      style: TextStyle(fontSize: 15, color: textColor),
                    ),
                  ],
                ],
              ),
            ),
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

class _FieldConfig {
  final String key;
  final String label;
  final String hint;
  final bool obscure;
  const _FieldConfig(this.key, this.label, this.hint, {this.obscure = false});
}
