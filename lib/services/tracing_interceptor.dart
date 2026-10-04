import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Перехватчик для сквозной трассировки сетевых запросов (X-Request-ID).
///
/// Автоматически генерирует UUID v4 для каждого исходящего запроса,
/// если он не был задан явно, и логирует идентификатор трассировки
/// при возникновении ошибок или успешных ответах.
class TracingInterceptor extends Interceptor {
  final Uuid _uuid;

  TracingInterceptor({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const String headerName = 'X-Request-ID';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hasRequestId = options.headers.keys.any(
      (k) => k.toLowerCase() == headerName.toLowerCase(),
    );

    if (!hasRequestId) {
      options.headers[headerName] = _uuid.v4();
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = extractResponseRequestId(response);
    if (kDebugMode) {
      debugPrint(
          '[Network Tracing] Success [$requestId]: ${response.requestOptions.method} ${response.requestOptions.uri} (${response.statusCode})');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = extractRequestId(err);
    final retryAfter = err.response?.headers.value('retry-after');
    final retrySuffix = (retryAfter != null && retryAfter.isNotEmpty)
        ? ' [Retry-After: ${retryAfter}s]'
        : '';
    if (kDebugMode) {
      debugPrint(
        'Request failed [$requestId]$retrySuffix: ${err.requestOptions.method} ${err.requestOptions.uri} '
        '(${err.response?.statusCode ?? "NO_RESPONSE"}) - ${err.message}',
      );
    }
    developer.log(
      'Request failed [$requestId]$retrySuffix: ${err.message}',
      name: 'TracingInterceptor',
      error: err,
      stackTrace: err.stackTrace,
    );
    super.onError(err, handler);
  }

  /// Извлекает X-Request-ID из заголовков ответа или запроса для DioException.
  static String extractRequestId(DioException err) {
    return err.response?.headers.value('x-request-id') ??
        err.response?.headers.value(headerName) ??
        err.requestOptions.headers[headerName]?.toString() ??
        err.requestOptions.headers['x-request-id']?.toString() ??
        'N/A';
  }

  /// Извлекает X-Request-ID из заголовков ответа или запроса для Response.
  static String extractResponseRequestId(Response response) {
    return response.headers.value('x-request-id') ??
        response.headers.value(headerName) ??
        response.requestOptions.headers[headerName]?.toString() ??
        response.requestOptions.headers['x-request-id']?.toString() ??
        'N/A';
  }
}
