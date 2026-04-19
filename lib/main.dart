import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/atalaya_localizations.dart';
import 'core/theme/pro_palette.dart';
import 'presentation/providers/app_settings_controller.dart';
import 'presentation/screens/auth_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final text = AtalayaTexts.of(settings.language);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: text.appTitle,
      theme: ProPalette.lightThemeData(),
      darkTheme: ProPalette.themeData(),
      themeMode: settings.themePreference.themeMode,
      home: const AuthGateScreen(),
    );
  }
}

class AtalayaApp extends StatelessWidget {
  const AtalayaApp({super.key});

  @override
  Widget build(BuildContext context) => const MyApp();
}
