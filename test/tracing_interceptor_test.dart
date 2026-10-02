import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_budget/services/tracing_interceptor.dart';

void main() {
  group('TracingInterceptor Tests', () {
    late Dio dio;
    late TracingInterceptor interceptor;

    setUp(() {
      interceptor = TracingInterceptor();
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      dio.interceptors.add(interceptor);
    });

    test('Automatically adds X-Request-ID header when not present', () async {
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        final requestId = options.headers[TracingInterceptor.headerName];
        expect(requestId, isNotNull);
        expect(requestId, isNotEmpty);
        // Valid UUID v4 regex
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(uuidRegex.hasMatch(requestId.toString()), isTrue);

        return ResponseBody.fromString(
          '{"status": "ok"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'x-request-id': [requestId.toString()],
          },
        );
      });

      final response = await dio.get('/health');
      expect(response.statusCode, 200);
      expect(response.requestOptions.headers.containsKey(TracingInterceptor.headerName), isTrue);
    });

    test('Preserves existing X-Request-ID header if already specified', () async {
      const customId = 'custom-trace-uuid-12345';

      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.headers[TracingInterceptor.headerName], equals(customId));
        return ResponseBody.fromString(
          '{"status": "ok"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'x-request-id': [customId],
          },
        );
      });

      final response = await dio.get(
        '/health',
        options: Options(headers: {'X-Request-ID': customId}),
      );

      expect(response.statusCode, 200);
      expect(response.requestOptions.headers['X-Request-ID'], equals(customId));
    });

    test('extractRequestId extracts from response headers on DioException', () {
      final reqOptions = RequestOptions(path: '/api');
      final resHeaders = Headers();
      resHeaders.add('x-request-id', 'trace-header-from-response');

      final exception = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 503,
          headers: resHeaders,
        ),
      );

      final id = TracingInterceptor.extractRequestId(exception);
      expect(id, equals('trace-header-from-response'));
    });

    test('extractRequestId falls back to requestOptions headers if response is null', () {
      final reqOptions = RequestOptions(
        path: '/api',
        headers: {'X-Request-ID': 'trace-from-request'},
      );

      final exception = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionError,
      );

      final id = TracingInterceptor.extractRequestId(exception);
      expect(id, equals('trace-from-request'));
    });

    test('extractRequestId returns N/A when no header is present anywhere', () {
      final reqOptions = RequestOptions(path: '/api');
      final exception = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.unknown,
      );

      final id = TracingInterceptor.extractRequestId(exception);
      expect(id, equals('N/A'));
    });

    test('extractResponseRequestId extracts from response and request', () {
      final reqOptions = RequestOptions(path: '/api');
      final headers = Headers();
      headers.add('x-request-id', 'res-trace-456');

      final response = Response(
        requestOptions: reqOptions,
        statusCode: 200,
        headers: headers,
      );

      expect(TracingInterceptor.extractResponseRequestId(response), equals('res-trace-456'));
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
