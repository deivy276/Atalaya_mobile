import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atalaya Mobile',
      theme: ProPalette.lightThemeData(),
      darkTheme: ProPalette.darkThemeData(),
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
