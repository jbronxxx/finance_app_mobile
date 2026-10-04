import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/screens/auth_screen.dart';
import 'package:getbalanceai_mobile/utils/app_error_handler.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:getbalanceai_mobile/widgets/app_alerts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async => ['wifi'],
    );
  });

  group('Password Validation Rules Tests', () {
    setUp(() {
      LanguageManager.setLanguage(AppLanguage.ru);
    });

    test('Empty or null password returns fill_all_fields error', () {
      expect(AuthScreen.validatePassword(null),
          equals(LanguageManager.t('fill_all_fields')));
      expect(AuthScreen.validatePassword(''),
          equals(LanguageManager.t('fill_all_fields')));
    });

    test('Password shorter than 6 characters is rejected', () {
      expect(AuthScreen.validatePassword('a1'),
          equals(LanguageManager.t('password_validation_error')));
      expect(AuthScreen.validatePassword('Pass1'),
          equals(LanguageManager.t('password_validation_error')));
    });

    test('Password exceeding 72 bytes is rejected', () {
      final longPasswordAscii = 'A1${'x' * 71}'; // 73 bytes
      expect(AuthScreen.validatePassword(longPasswordAscii),
          equals(LanguageManager.t('password_too_long_bytes')));

      final longPasswordUtf8 = 'A1${'я' * 36}'; // 2 + 36 * 2 = 74 bytes
      expect(AuthScreen.validatePassword(longPasswordUtf8),
          equals(LanguageManager.t('password_too_long_bytes')));
    });

    test('Password without letters is rejected', () {
      expect(AuthScreen.validatePassword('123456'),
          equals(LanguageManager.t('password_validation_error')));
      expect(AuthScreen.validatePassword('1234567890'),
          equals(LanguageManager.t('password_validation_error')));
    });

    test('Password without numbers is rejected', () {
      expect(AuthScreen.validatePassword('password'),
          equals(LanguageManager.t('password_validation_error')));
      expect(AuthScreen.validatePassword('StrongPassword'),
          equals(LanguageManager.t('password_validation_error')));
    });

    test('Valid passwords (6-72 chars, letter + digit) are accepted', () {
      expect(AuthScreen.validatePassword('pass12'), isNull);
      expect(AuthScreen.validatePassword('SecurePass1'), isNull);
      expect(AuthScreen.validatePassword('P@ssw0rd!2026'), isNull);
      expect(AuthScreen.validatePassword('пароль123'), isNull);

      // Exact boundary limits: 6 chars and 72 chars
      final minBoundary = 'a1${'b' * 4}';
      expect(minBoundary.length, equals(6));
      expect(AuthScreen.validatePassword(minBoundary), isNull);

      final maxBoundary = 'a1${'b' * 70}';
      expect(maxBoundary.length, equals(72));
      expect(AuthScreen.validatePassword(maxBoundary), isNull);

      final maxBoundaryUtf8 =
          'a1${'я' * 35}'; // 2 + 35 * 2 = 72 bytes, 37 characters
      expect(AuthScreen.validatePassword(maxBoundaryUtf8), isNull);
    });
  });

  group('Rate Limiting (HTTP 429 & RATE_LIMIT_EXCEEDED) Tests', () {
    setUp(() {
      LanguageManager.setLanguage(AppLanguage.ru);
    });

    test('AppErrorHandler.getMessage formats HTTP 429 without custom body', () {
      final reqOptions = RequestOptions(path: '/api/v1/insights/');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 429,
          data: null,
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(msg, equals(LanguageManager.t('http_429')));
      expect(msg, contains('Превышен лимит запросов'));
    });

    test('AppErrorHandler.getMessage formats RATE_LIMIT_EXCEEDED error payload',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/auth/login');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 429,
          data: {
            'status': 'error',
            'code': 'RATE_LIMIT_EXCEEDED',
            'message':
                'Превышен лимит запросов. Пожалуйста, повторите попытку позже.',
            'details': {'limit': '5 per 1 minute'},
          },
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(
          msg,
          equals(
              'Превышен лимит запросов. Пожалуйста, повторите попытку позже.'));
    });

    test('AppErrorHandler.getMessage handles VALIDATION_ERROR field message',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/auth/register');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 422,
          data: {
            'status': 'error',
            'code': 'VALIDATION_ERROR',
            'message': 'Validation failed',
            'details': {
              'fields': {
                'password':
                    'Пароль должен содержать минимум 6 символов, 1 букву и 1 цифру',
              },
            },
          },
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(
          msg,
          equals(
              'Пароль должен содержать минимум 6 символов, 1 букву и 1 цифру'));
    });

    testWidgets(
        'AppErrorHandler.show displays RateLimitDialog on 429 with retry-after header',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.ru);
      final reqOptions = RequestOptions(path: '/api/v1/auth/login');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['15'],
          }),
          data: {
            'status': 'error',
            'code': 'RATE_LIMIT_EXCEEDED',
            'message': 'Слишком много попыток входа.',
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppErrorHandler.show(context, err),
                child: const Text('Trigger 429'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger 429'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Слишком много попыток входа.'), findsOneWidget);
      expect(find.textContaining('15'), findsOneWidget);
    });

    testWidgets(
        'AppAlerts.showRateLimitDialog countdown decrements and enables actions',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.ru);
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppAlerts.showRateLimitDialog(
                    context,
                    title: 'Лимит исчерпан',
                    message: 'Подождите немного',
                    retryAfterSeconds: 2,
                    onRetry: () => retried = true,
                  );
                },
                child: const Text('Open Rate Limit'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rate Limit'));
      await tester.pumpAndSettle();

      expect(find.text('Лимит исчерпан'), findsOneWidget);
      expect(find.text('Подождите немного'), findsOneWidget);
      expect(find.textContaining('2'), findsOneWidget);

      // Advance clock by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('1'), findsOneWidget);

      // Advance clock by another second
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(LanguageManager.t('rate_limit_ready')), findsOneWidget);

      // Retry button is now visible
      expect(find.text(LanguageManager.t('service_unavailable_retry')),
          findsOneWidget);
      await tester
          .tap(find.text(LanguageManager.t('service_unavailable_retry')));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });
  });

  group('AuthScreen Registration UI Validation Tests', () {
    testWidgets(
        'Password helper hint appears in register mode and validation prevents submission',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.ru);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );

      // Initial mode is Login: no password requirements helper text
      expect(find.text(LanguageManager.t('password_requirements_hint')),
          findsNothing);

      // Switch to Register mode
      await tester.tap(find.text(LanguageManager.t('no_account_prompt')));
      await tester.pumpAndSettle();

      // Password requirements hint is visible
      expect(find.text(LanguageManager.t('password_requirements_hint')),
          findsOneWidget);

      // Enter name, email, and short password (<6 chars)
      await tester.enterText(
          find.widgetWithText(TextField, LanguageManager.t('name_label')),
          'Alex');
      await tester.enterText(
          find.widgetWithText(TextField, LanguageManager.t('email_label')),
          'alex@example.com');
      await tester.enterText(
          find.widgetWithText(TextField, LanguageManager.t('password_label')),
          '12345');

      await tester.tap(find.text(LanguageManager.t('register_btn')));
      await tester.pump();

      // SnackBar with password validation error is shown
      expect(find.text(LanguageManager.t('password_validation_error')),
          findsOneWidget);
    });
  });
}
