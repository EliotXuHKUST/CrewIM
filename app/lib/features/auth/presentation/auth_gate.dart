import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../../session/presentation/session_chat_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await AuthStorage.getToken();
    if (token != null && token.isNotEmpty) {
      apiClient.setToken(token);
      if (mounted) setState(() { _authenticated = true; _checking = false; });
    } else {
      if (mounted) setState(() { _authenticated = false; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return _authenticated ? const SessionChatScreen() : const LoginScreen();
  }
}
