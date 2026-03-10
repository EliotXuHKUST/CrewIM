import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../../session/presentation/session_chat_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  Widget? _target;

  static const _onboardingKey = 'onboarding_completed';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(_onboardingKey) ?? false;

    if (!onboardingDone) {
      await prefs.setBool(_onboardingKey, true);
      if (mounted) setState(() { _target = const OnboardingScreen(); _checking = false; });
      return;
    }

    final token = await AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setToken(token);
      if (mounted) setState(() { _target = const SessionChatScreen(); _checking = false; });
    } else {
      if (mounted) setState(() { _target = const LoginScreen(); _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _target!;
  }
}
