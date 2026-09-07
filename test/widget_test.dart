import 'package:flutter_test/flutter_test.dart';

import 'package:family_budget/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinanceApp());

    // Verify that our app starts and shows the title or general elements.
    expect(find.text('Сентябрь 2026'), findsOneWidget);
  });
}
