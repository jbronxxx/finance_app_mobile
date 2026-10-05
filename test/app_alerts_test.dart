import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/widgets/app_alerts.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';

void main() {
  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets(
      'AppAlerts.success shows SnackBar with check_circle_rounded icon and text',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              AppAlerts.success(context, 'Успешная операция');
            },
            child: const Text('Show Alert'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Alert'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 500)); // Let it settle

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Успешная операция'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('AppAlerts.error shows SnackBar with error_rounded icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              AppAlerts.error(context, 'Ошибка сервера', title: 'Внимание');
            },
            child: const Text('Show Alert'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Внимание'), findsOneWidget); // Title should be visible
    expect(find.text('Ошибка сервера'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('AppAlerts.noInternet shows unified network error message',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              AppAlerts.noInternet(context);
            },
            child: const Text('Show Alert'),
          );
        },
      ),
    ));

    await tester.tap(find.text('Show Alert'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);

    // Check if the unified text from LanguageManager is shown
    final expectedText = LanguageManager.l10n.no_internet_connection;
    expect(find.text(expectedText), findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
  });
}
