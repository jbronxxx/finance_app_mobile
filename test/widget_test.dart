import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_budget/main.dart';
import 'package:family_budget/services/local_db_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // path_provider не имеет платформенной реализации в `flutter test` (нет
    // реального устройства/эмулятора) — подменяем канал временной папкой,
    // чтобы LocalDbService.init() мог открыть ObjectBox.
    final tempDir = await Directory.systemTemp.createTemp('finance_app_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    // dotenv.testLoad не требует физического .env-файла — подходит для тестов.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
    await LocalDbService.init();
  });

  testWidgets('Приложение запускается и показывает нижнюю навигацию', (tester) async {
    await tester.pumpWidget(const FinanceApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Баланс'), findsOneWidget);
    expect(find.text('Лимиты'), findsOneWidget);
  });
}
