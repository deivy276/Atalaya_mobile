import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atalaya_mobile/presentation/screens/dashboard_screen.dart';

void main() {
  testWidgets(
    'dashboard screen mounts base scaffold',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    },
    skip: 'Habilitar cuando se inyecten providers de prueba para DashboardScreen.',
  );
}
