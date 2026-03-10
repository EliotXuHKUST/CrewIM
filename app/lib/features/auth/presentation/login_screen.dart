import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import 'auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _phoneValid => RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text.trim());

  Future<void> _sendCode() async {
    if (!_phoneValid || _countdown > 0) return;
    setState(() => _error = null);

    try {
      await apiClient.sendSmsCode(_phoneController.text.trim());
      setState(() => _countdown = 60);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _countdown--;
          if (_countdown <= 0) t.cancel();
        });
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (!_phoneValid || code.length != 6) return;

    setState(() { _loading = true; _error = null; });

    try {
      final result = await apiClient.login(phone, code);
      final token = result['token'] as String?;
      final user = result['user'] as Map<String, dynamic>?;
      if (token != null) {
        await AuthStorage.saveToken(token);
        if (user != null) {
          await AuthStorage.saveUserInfo(
            userId: user['id'] as String? ?? '',
            phone: user['phone'] as String? ?? phone,
          );
        }
        syncEngine.start();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final fillColor = isDark ? AppColors.inputFillDark : AppColors.inputFill;
    final accentColor = isDark ? AppColors.accentDark : AppColors.accent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                '知知',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: textColor, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                '你的 AI 参谋团队',
                style: TextStyle(fontSize: 14, color: secondaryColor),
              ),
              const SizedBox(height: 48),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '手机号',
                  counterText: '',
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '验证码',
                        counterText: '',
                        filled: true,
                        fillColor: fillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: _phoneValid && _countdown == 0 ? _sendCode : null,
                      style: TextButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        _countdown > 0 ? '${_countdown}s' : '获取验证码',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _phoneValid && _codeController.text.trim().length == 6 && !_loading
                      ? _login
                      : null,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),

              const Spacer(flex: 4),

              Text(
                '登录即表示同意《用户协议》和《隐私政策》',
                style: TextStyle(fontSize: 11, color: secondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
