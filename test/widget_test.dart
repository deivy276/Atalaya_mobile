import 'package:flutter_test/flutter_test.dart';

import 'package:atalaya_mobile/main.dart';

void main() {
  testWidgets('atalaya app loads root widget', (WidgetTester tester) async {
    await tester.pumpWidget(const AtalayaApp());
    expect(find.text('Atalaya Mobile'), findsOneWidget);
  });
}
