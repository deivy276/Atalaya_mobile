import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atalaya_mobile/core/theme/pro_palette.dart';

void main() {
  testWidgets('smoke: app shell renders with Atalaya theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        title: 'Atalaya Mobile',
        theme: ProPalette.themeData(),
        home: const Scaffold(body: Text('smoke-ok')),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('smoke-ok'), findsOneWidget);
  });
}
