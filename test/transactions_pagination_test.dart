import 'package:dio/dio.dart';
import 'package:family_budget/models/local_db_models.dart';
import 'package:family_budget/models/paginated_response.dart';
import 'package:family_budget/models/transaction_model.dart';
import 'package:family_budget/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, String> mockSecureStorage = {};

  setUpAll(() {
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

  group('Transactions Pagination Contract & Model Tests', () {
    test('PaginatedResponse parses json correctly and calculates hasMore', () {
      final json = {
        'items': [
          {
            'id': '550e8400-e29b-41d4-a716-446655440001',
            'amount': 1500.50,
            'description': 'Зарплата',
            'category': 'salary',
            'type': 'income',
            'date': '2026-09-10T10:00:00Z',
            'created_at': '2026-09-10T10:30:00Z',
          }
        ],
        'total': 120,
        'limit': 50,
        'offset': 0,
      };

      final paginated = PaginatedResponse<TransactionModel>.fromJson(
        json,
        (item) => TransactionModel.fromJson(item as Map<String, dynamic>),
      );

      expect(paginated.total, 120);
      expect(paginated.limit, 50);
      expect(paginated.offset, 0);
      expect(paginated.items.length, 1);
      expect(paginated.hasMore, isTrue);

      final tx = paginated.items.first;
      expect(tx.id, '550e8400-e29b-41d4-a716-446655440001');
      expect(tx.amount, 1500.50);
      expect(tx.description, 'Зарплата');
      expect(tx.category, 'salary');
      expect(tx.type, 'income');
      expect(tx.createdAt, isNotNull);
      expect(tx.createdAt!.toUtc().toIso8601String(), '2026-09-10T10:30:00.000Z');
    });

    test('PaginatedResponse hasMore is false when on last page', () {
      final json = {
        'items': [
          {
            'id': 'tx-1',
            'amount': 100.0,
            'description': 'Item',
            'category': 'food',
            'type': 'expense',
            'date': '2026-09-10T10:00:00Z',
          }
        ],
        'total': 1,
        'limit': 50,
        'offset': 0,
      };

      final paginated = PaginatedResponse<TransactionModel>.fromJson(
        json,
        (item) => TransactionModel.fromJson(item as Map<String, dynamic>),
      );

      expect(paginated.hasMore, isFalse);
    });

    test('TransactionModel parses created_at and date_created safely', () {
      final jsonWithCreatedAt = {
        'id': 'tx-c1',
        'amount': '250.00',
        'description': 'Lunch',
        'category': 'food',
        'type': 'expense',
        'date': '2026-09-11T12:00:00Z',
        'created_at': '2026-09-11T12:05:00Z',
      };

      final tx1 = TransactionModel.fromJson(jsonWithCreatedAt);
      expect(tx1.createdAt, isNotNull);
      expect(tx1.createdAt!.toUtc().toIso8601String(), '2026-09-11T12:05:00.000Z');
      expect(tx1.toJson()['created_at'], '2026-09-11T12:05:00.000Z');

      final jsonWithDateCreated = {
        'id': 'tx-c2',
        'amount': 300,
        'description': 'Taxi',
        'category': 'transport',
        'type': 'expense',
        'date': '2026-09-11T13:00:00Z',
        'date_created': '2026-09-11T13:05:00Z',
      };

      final tx2 = TransactionModel.fromJson(jsonWithDateCreated);
      expect(tx2.createdAt, isNotNull);
      expect(tx2.createdAt!.toUtc().toIso8601String(), '2026-09-11T13:05:00.000Z');
    });

    test('Transaction entity in local_db_models parses created_at correctly', () {
      final json = {
        'id': 'tx-local-1',
        'amount': 500.0,
        'description': 'Gift',
        'category': 'other',
        'type': 'income',
        'date': '2026-09-12T10:00:00Z',
        'created_at': '2026-09-12T10:15:00Z',
      };

      final tx = Transaction.fromJson(json);
      expect(tx.serverId, 'tx-local-1');
      expect(
        DateTime.fromMillisecondsSinceEpoch(tx.dateCreatedMilliseconds).toUtc().toIso8601String(),
        '2026-09-12T10:15:00.000Z',
      );
    });

    test('ApiService.getTransactions sends limit, offset, since and parses PaginatedResponse', () async {
      final api = ApiService.instance;
      await api.setTokens('test_access_token', 'test_refresh_token');

      Map<String, dynamic>? capturedQueryParams;
      Map<String, dynamic>? capturedHeaders;

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions/')) {
            capturedQueryParams = options.queryParameters;
            capturedHeaders = options.headers;

            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': {
                  'items': [
                    {
                      'id': '550e8400-e29b-41d4-a716-446655440001',
                      'amount': 1500.50,
                      'description': 'Зарплата',
                      'category': 'salary',
                      'type': 'income',
                      'date': '2026-09-10T10:00:00Z',
                      'created_at': '2026-09-10T10:30:00Z',
                    }
                  ],
                  'total': 120,
                  'limit': 25,
                  'offset': 10,
                },
              },
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        final sinceDate = DateTime.utc(2026, 9, 1);
        final result = await api.getTransactions(
          limit: 25,
          offset: 10,
          since: sinceDate,
        );

        expect(capturedQueryParams, isNotNull);
        expect(capturedQueryParams!['limit'], 25);
        expect(capturedQueryParams!['offset'], 10);
        expect(capturedQueryParams!['since'], '2026-09-01T00:00:00.000Z');
        expect(capturedHeaders!['Authorization'], 'Bearer test_access_token');

        expect(result.total, 120);
        expect(result.limit, 25);
        expect(result.offset, 10);
        expect(result.items.length, 1);
        expect(result.items.first.id, '550e8400-e29b-41d4-a716-446655440001');
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test('ApiService.getTransactions clamps limit to 1..100 and clamps offset >= 0', () async {
      final api = ApiService.instance;
      await api.setTokens('test_token', 'test_refresh');

      Map<String, dynamic>? capturedQueryParams;

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions/')) {
            capturedQueryParams = options.queryParameters;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': {
                  'items': [],
                  'total': 0,
                  'limit': 100,
                  'offset': 0,
                },
              },
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        // limit > 100 should clamp to 100, offset < 0 should clamp to 0
        await api.getTransactions(limit: 500, offset: -5);
        expect(capturedQueryParams!['limit'], 100);
        expect(capturedQueryParams!['offset'], 0);

        // limit < 1 should clamp to 1
        await api.getTransactions(limit: 0, offset: 5);
        expect(capturedQueryParams!['limit'], 1);
        expect(capturedQueryParams!['offset'], 5);
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });

    test('ApiService.getTransactions supports legacy flat array response gracefully', () async {
      final api = ApiService.instance;
      await api.setTokens('test_token', 'test_refresh');

      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/transactions/')) {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': [
                  {
                    'id': 'legacy-tx-1',
                    'amount': 99.9,
                    'description': 'Coffee',
                    'category': 'food',
                    'type': 'expense',
                    'date': '2026-09-10T10:00:00Z',
                  }
                ],
              },
            ));
          }
          return handler.next(options);
        },
      );

      api.dio.interceptors.insert(0, interceptor);

      try {
        final result = await api.getTransactions();
        expect(result.items.length, 1);
        expect(result.total, 1);
        expect(result.items.first.id, 'legacy-tx-1');
      } finally {
        api.dio.interceptors.remove(interceptor);
      }
    });
  });
}
