import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  bool _loading = false;
  String? _error;
  String _mode = 'main'; // main, phone, email

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _emailController.dispose();
    _emailCodeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _phoneValid => RegExp(r'^1[3-9]\d{9}$').hasMatch(_phoneController.text.trim());
  bool get _emailValid => _emailController.text.trim().contains('@');

  Future<void> _loginSuccess(Map<String, dynamic> result) async {
    final token = result['token'] as String?;
    final user = result['user'] as Map<String, dynamic>?;
    if (token != null) {
      await AuthStorage.saveToken(token);
      if (user != null) {
        await AuthStorage.saveUserInfo(
          userId: user['id'] as String? ?? '',
          phone: user['phone'] as String? ?? '',
        );
      }
      syncEngine.start();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _loading = true; _error = null; });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final name = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty).join(' ');
      final result = await apiClient.loginWithApple(
        credential.identityToken!,
        displayName: name.isNotEmpty ? name : null,
      );
      await _loginSuccess(result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final result = await apiClient.loginWithGoogle(
        auth.idToken!,
        displayName: googleUser.displayName,
      );
      await _loginSuccess(result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendSmsCode() async {
    if (!_phoneValid || _countdown > 0) return;
    setState(() => _error = null);
    try {
      await apiClient.sendSmsCode(_phoneController.text.trim());
      _startCountdown();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _sendEmailCode() async {
    if (!_emailValid || _countdown > 0) return;
    setState(() => _error = null);
    try {
      await apiClient.sendEmailCode(_emailController.text.trim());
      _startCountdown();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _countdown--; if (_countdown <= 0) t.cancel(); });
    });
  }

  Future<void> _loginWithPhone() async {
    if (!_phoneValid || _codeController.text.trim().length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await apiClient.login(_phoneController.text.trim(), _codeController.text.trim());
      await _loginSuccess(result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithEmail() async {
    if (!_emailValid || _emailCodeController.text.trim().length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await apiClient.loginWithEmail(_emailController.text.trim(), _emailCodeController.text.trim());
      await _loginSuccess(result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fillColor = AppColors.inputFill;
    final accentColor = AppColors.accent;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Text(
                l10n.appName,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(l10n.appSubtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 48),

              if (_mode == 'main') ...[
                _buildAppleButton(l10n),
                const SizedBox(height: 12),
                _buildGoogleButton(l10n),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.separator)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(l10n.orLoginWith, style: const TextStyle(fontSize: 13, color: AppColors.textPlaceholder)),
                    ),
                    const Expanded(child: Divider(color: AppColors.separator)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _mode = 'phone'),
                      child: Text(l10n.phoneLogin, style: TextStyle(color: accentColor, fontSize: 14)),
                    ),
                    const SizedBox(width: 24),
                    TextButton(
                      onPressed: () => setState(() => _mode = 'email'),
                      child: Text(l10n.emailLogin, style: TextStyle(color: accentColor, fontSize: 14)),
                    ),
                  ],
                ),
              ],

              if (_mode == 'phone') ...[
                _buildPhoneForm(l10n, fillColor, accentColor),
              ],

              if (_mode == 'email') ...[
                _buildEmailForm(l10n, fillColor, accentColor),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error), textAlign: TextAlign.center),
              ],

              if (_mode != 'main') ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() { _mode = 'main'; _error = null; }),
                  child: Text('← ${l10n.cancel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
              ],

              const Spacer(flex: 4),
              Text(
                l10n.loginAgreement,
                style: const TextStyle(fontSize: 11, color: AppColors.textPlaceholder),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _signInWithApple,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        icon: const Icon(Icons.apple, size: 22),
        label: Text(l10n.signInWithApple, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildGoogleButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.separator),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
        label: Text(l10n.signInWithGoogle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildPhoneForm(AppLocalizations l10n, Color fillColor, Color accentColor) {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.phone, counterText: '', filled: true, fillColor: fillColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
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
                  hintText: l10n.verificationCode, counterText: '', filled: true, fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _phoneValid && _countdown == 0 ? _sendSmsCode : null,
              child: Text(_countdown > 0 ? l10n.countdownSeconds(_countdown) : l10n.getCode),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _phoneValid && _codeController.text.trim().length == 6 && !_loading ? _loginWithPhone : null,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.login),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n, Color fillColor, Color accentColor) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.email, filled: true, fillColor: fillColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailCodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.verificationCode, counterText: '', filled: true, fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _emailValid && _countdown == 0 ? _sendEmailCode : null,
              child: Text(_countdown > 0 ? l10n.countdownSeconds(_countdown) : l10n.getCode),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _emailValid && _emailCodeController.text.trim().length == 6 && !_loading ? _loginWithEmail : null,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.login),
          ),
        ),
      ],
    );
  }
}
