import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

final localeNotifier = ValueNotifier<Locale?>(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final savedLocale = prefs.getString('app_locale');
  if (savedLocale != null) {
    localeNotifier.value = Locale(savedLocale);
  }

  runApp(const ZhiZhiApp());
}

class ZhiZhiApp extends StatelessWidget {
  const ZhiZhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          title: '知知',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          initialRoute: '/',
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
