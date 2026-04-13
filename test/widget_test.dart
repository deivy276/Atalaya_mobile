import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atalaya_mobile/main.dart';

void main() {
  testWidgets('atalaya app builds with provider scope', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtalayaApp()));
    await tester.pump();

    expect(find.byType(AtalayaApp), findsOneWidget);
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
