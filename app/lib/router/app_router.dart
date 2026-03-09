import 'package:flutter/material.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/session/presentation/session_list_screen.dart';
import '../features/session/presentation/session_chat_screen.dart';
import '../features/command/presentation/command_screen.dart';
import '../features/task/presentation/task_detail_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/onboarding':
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case '/sessions':
        return MaterialPageRoute(builder: (_) => const SessionListScreen());
      case '/old-command':
        return MaterialPageRoute(builder: (_) => const CommandScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        if (settings.name?.startsWith('/session/') ?? false) {
          final sessionId = settings.name!.replaceFirst('/session/', '');
          return MaterialPageRoute(
            builder: (_) => SessionChatScreen(sessionId: sessionId),
          );
        }
        if (settings.name?.startsWith('/task/') ?? false) {
          final taskId = settings.name!.replaceFirst('/task/', '');
          return MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: taskId),
          );
        }
        return MaterialPageRoute(builder: (_) => const AuthGate());
    }
  }
}
