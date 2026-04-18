import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/pro_palette.dart';
import 'presentation/screens/auth_gate_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: AtalayaApp(),
    );
  }
}

class AtalayaApp extends StatelessWidget {
  const AtalayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atalaya Mobile',
      theme: ProPalette.themeData(),
      home: const AuthGateScreen(),
    );
  }
}