import 'package:getbalanceai_mobile/utils/utils.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:getbalanceai_mobile/config/api_config.dart';
import 'package:getbalanceai_mobile/models/auth_model.dart';
import 'package:getbalanceai_mobile/models/budget_model.dart';
import 'package:getbalanceai_mobile/models/local_db_models.dart';
import 'package:getbalanceai_mobile/models/sync_model.dart';
import 'package:getbalanceai_mobile/models/transaction_model.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';

void main() {
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') {
          final key = methodCall.arguments['key'] as String;
          return mockSecureStorage[key];
        } else if (methodCall.method == 'write') {
          final key = methodCall.arguments['key'] as String;
          final value = methodCall.arguments['value'] as String;
          mockSecureStorage[key] = value;
          return null;
        } else if (methodCall.method == 'delete') {
          final key = methodCall.arguments['key'] as String;
          mockSecureStorage.remove(key);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          mockSecureStorage.clear();
          return null;
        }
        return null;
      },
    );
  });

  setUp(() {
    mockSecureStorage.clear();
  });

  group('1. Timestamps and UTC ISO 8601 Parsing & Serialization', () {
    test('parseServerDate parses UTC ISO 8601 strings to local DateTime', () {
      const utcString = '2026-10-03T12:00:00Z';
      final parsed = parseServerDate(utcString);
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed.toUtc().toIso8601String(), '2026-10-03T12:00:00.000Z');

      const offsetString = '2026-10-03T15:00:00+03:00';
      final parsedOffset = parseServerDate(offsetString);
      expect(parsedOffset, isNotNull);
      expect(
          parsedOffset!.toUtc().toIso8601String(), '2026-10-03T12:00:00.000Z');

      expect(parseServerDate(null), isNull);
      expect(parseServerDate(123), isNull);
    });

    test('Transaction parses date as local and serializes date to UTC ISO 8601',
        () {
      final json = {
        'id': 'tx-123',
        'amount': 450.50,
        'description': 'Grocery store',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-03T12:00:00Z',
      };

      final transaction = Transaction.fromJson(json);
      expect(transaction.serverId, 'tx-123');
      expect(transaction.amount, 450.50);
      expect(transaction.date.isUtc, isFalse);
      expect(transaction.date.millisecondsSinceEpoch,
          DateTime.parse('2026-10-03T12:00:00Z').millisecondsSinceEpoch);

      final outputJson = transaction.toJson();
      expect(outputJson['date'], '2026-10-03T12:00:00.000Z');
      expect(outputJson['amount'], 450.50);
      expect(outputJson['category'], 'food');
      expect(outputJson['type'], 'expense');
    });

    test('TransactionModel parses date toLocal and serializes to UTC', () {
      final json = {
        'id': 'tx-999',
        'amount': 1200.0,
        'description': 'Freelance',
        'category': 'salary',
        'type': 'income',
        'date': '2026-10-03T08:30:00+00:00',
      };

      final model = TransactionModel.fromJson(json);
      expect(model.id, 'tx-999');
      expect(model.date.isUtc, isFalse);
      expect(model.date.toUtc().toIso8601String(), '2026-10-03T08:30:00.000Z');

      final serialized = model.toJson();
      expect(serialized['date'], '2026-10-03T08:30:00.000Z');
      expect(serialized['id'], 'tx-999');
    });

    test('AuthMeResponseModel parses created_at to local DateTime', () {
      final json = {
        'status': 'success',
        'data': {
          'id': 'usr-1',
          'email': 'user@example.com',
          'name': 'Test User',
          'created_at': '2026-10-01T10:00:00Z',
        }
      };

      final authMe = AuthMeResponseModel.fromJson(json);
      expect(authMe.id, 'usr-1');
      expect(authMe.userEmail, 'user@example.com');
      expect(authMe.userName, 'Test User');
      expect(authMe.createdAt, isNotNull);
      expect(authMe.createdAt!.isUtc, isFalse);
      expect(authMe.createdAt!.toUtc().toIso8601String(),
          '2026-10-01T10:00:00.000Z');
    });
  });

  group('2. JWT Authentication & Dio 401 Refresh Flow', () {
    test('LoginResponseModel parses access_token and refresh_token', () {
      final json = {
        'status': 'success',
        'data': {
          'access_token': 'jwt_access_with_jti_123',
          'refresh_token': 'jwt_refresh_with_jti_456',
          'token_type': 'bearer',
        }
      };

      final loginRes = LoginResponseModel.fromJson(json);
      expect(loginRes.accessToken, 'jwt_access_with_jti_123');
      expect(loginRes.refreshToken, 'jwt_refresh_with_jti_456');
      expect(loginRes.tokenType, 'bearer');
    });

    test(
        'Dio Interceptor handles 401, refreshes tokens with jti, saves to secure storage and retries original request',
        () async {
      final api = ApiService.instance;
      await api.init();
      await api.setTokens('expired_access_token', 'initial_refresh_token');

      // Создаем кастомный HttpClientAdapter для тестирования перехватчика
      bool refreshCalled = false;
      Map<String, dynamic>? refreshPayload;
      int protectedEndpointCallCount = 0;

      api.dio.httpClientAdapter = _MockDioAdapter((RequestOptions options) {
        if (options.path == ApiConfig.refreshToken) {
          refreshCalled = true;
          refreshPayload = options.data is Map
              ? Map<String, dynamic>.from(options.data)
              : null;

          return ResponseBody.fromString(
            jsonEncode({
              'status': 'success',
              'data': {
                'access_token': 'new_jwt_access_jti_789',
                'refresh_token': 'new_jwt_refresh_jti_999',
                'token_type': 'bearer',
              }
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (options.path == ApiConfig.insights) {
          protectedEndpointCallCount++;
          final authHeader = options.headers['Authorization'] as String?;

          // Первый вызов со старым токеном возвращает 401
          if (authHeader == 'Bearer expired_access_token') {
            return ResponseBody.fromString(
              jsonEncode({'detail': 'Token expired'}),
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          // Повторный вызов с новым токеном возвращает 200
          if (authHeader == 'Bearer new_jwt_access_jti_789') {
            return ResponseBody.fromString(
              jsonEncode({
                'status': 'success',
                'data': {
                  'insights': ['Good spending habits'],
                  'generated_at': '2026-10-03T12:00:00Z',
                }
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          return ResponseBody.fromString(
              jsonEncode({'error': 'Unauthorized'}), 401);
        }

        return ResponseBody.fromString('{}', 404);
      });

      final result = await api.getInsights();

      expect(refreshCalled, isTrue);
      expect(refreshPayload, isNotNull);
      expect(refreshPayload!['refresh_token'], 'initial_refresh_token');
      expect(protectedEndpointCallCount, 2);
      expect(result['insights'], ['Good spending habits']);

      // Проверяем сохранение новой пары токенов в FlutterSecureStorage
      expect(mockSecureStorage['auth_token'], 'new_jwt_access_jti_789');
      expect(mockSecureStorage['refresh_token'], 'new_jwt_refresh_jti_999');
    });

    test(
        'refreshAuthTokens directly requests /auth/refresh and updates storage',
        () async {
      final api = ApiService.instance;
      await api.setTokens('access_old', 'refresh_jwt_jti_111');

      bool refreshEndpointHit = false;
      api.dio.httpClientAdapter = _MockDioAdapter((RequestOptions options) {
        if (options.path == ApiConfig.refreshToken) {
          refreshEndpointHit = true;
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'access_token': 'access_new_jti_222',
                'refresh_token': 'refresh_new_jti_333',
              }
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final success = await api.refreshAuthTokens();
      expect(success, isTrue);
      expect(refreshEndpointHit, isTrue);
      expect(mockSecureStorage['auth_token'], 'access_new_jti_222');
      expect(mockSecureStorage['refresh_token'], 'refresh_new_jti_333');
    });
  });

  group('3. Offline Batch Sync (POST /api/v1/sync/) & Budget Deletion', () {
    test('Budget.toJson supports isDeleted flag', () {
      final budget = Budget(
        localId: 1,
        serverId: 'budget-uuid-123',
        dbCategory: 'food',
        limitAmount: 500000.0,
        month: 10,
        year: 2026,
        spent: 100000.0,
        remaining: 400000.0,
      );

      final normalJson = budget.toJson();
      expect(normalJson['id'], 'budget-uuid-123');
      expect(normalJson['category'], 'food');
      expect(normalJson['limit_amount'], 500000.0);
      expect(normalJson['month'], 10);
      expect(normalJson['year'], 2026);
      expect(normalJson.containsKey('is_deleted'), isFalse);

      final deletedJson = budget.toJson(isDeleted: true);
      expect(deletedJson['is_deleted'], isTrue);
      expect(deletedJson['id'], 'budget-uuid-123');
    });

    test('BudgetModel supports id, isDeleted in fromJson and toJson', () {
      final model = BudgetModel(
        id: 'budget-uuid-456',
        category: 'transport',
        limitAmount: 300000.0,
        month: 10,
        year: 2026,
        isDeleted: true,
      );

      final json = model.toJson();
      expect(json['id'], 'budget-uuid-456');
      expect(json['category'], 'transport');
      expect(json['is_deleted'], isTrue);

      final parsed = BudgetModel.fromJson(json);
      expect(parsed.id, 'budget-uuid-456');
      expect(parsed.isDeleted, isTrue);
      expect(parsed.category, 'transport');
    });

    test('SyncModel serializes transactions, budgets and deleted_budget_ids',
        () {
      final syncPayload = SyncModel(
        transactions: [
          {
            'amount': 150.0,
            'category': 'food',
            'type': 'expense',
            'date': '2026-10-03T12:00:00.000Z',
          }
        ],
        budgets: [
          {
            'id': 'b-1',
            'category': 'food',
            'limit_amount': 500.0,
            'month': 10,
            'year': 2026,
          },
          {
            'id': 'b-deleted-uuid-789',
            'is_deleted': true,
          }
        ],
        deletedBudgetIds: ['b-deleted-uuid-789'],
        deletedTransactionIds: ['tx-deleted-uuid-001'],
      );

      final json = syncPayload.toJson();
      expect(json['transactions'].length, 1);
      expect(json['budgets'].length, 2);
      expect(json['budgets'][1]['is_deleted'], isTrue);
      expect(json['deleted_budget_ids'], ['b-deleted-uuid-789']);
      expect(json['deleted_transaction_ids'], ['tx-deleted-uuid-001']);
    });
  });
}

class _MockDioAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
