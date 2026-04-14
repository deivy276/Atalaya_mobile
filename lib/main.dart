import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/feature_flags.dart';
import 'core/theme/pro_palette.dart';
import 'presentation/screens/dashboard_v2_screen.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AtalayaApp()));
}

class AtalayaApp extends StatelessWidget {
  const AtalayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Atalaya Mobile',
      theme: ProPalette.themeData(),
      home: FeatureFlags.mobileDashboardV2 ? const DashboardV2Screen() : const DashboardScreen(),
    );
  }
}
