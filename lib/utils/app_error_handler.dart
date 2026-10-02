import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../widgets/app_alerts.dart';
import '../utils/language_manager.dart';
import '../main.dart';

/// Централизованный обработчик ошибок приложения.
/// 
/// Отвечает за преобразование технических исключений (сетевых, серверных) 
/// в понятные пользователю сообщения и их отображение в UI.
class AppErrorHandler {
  /// Возвращает текстовое сообщение на основе типа ошибки.
  static String getMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    return error.toString();
  }

  /// Показывает уведомление об ошибке пользователю.
  /// 
  /// В случае истечения сессии (401 или специальные коды) отображает модальный диалог.
  static void show(BuildContext context, dynamic error, {String? title}) {
    final message = getMessage(error);
    
    if (error is DioException) {
      final data = error.response?.data;
      final code = (data is Map) ? data['code'] : null;

      // Обработка истечения срока действия сессии
      if (error.response?.statusCode == 401 || 
          code == 'EXPIRED_TOKEN' || 
          code == 'INVALID_TOKEN' || 
          code == 'TOKEN_REVOKED') {
        
        AppAlerts.showErrorDialog(
          context,
          title: LanguageManager.t('session_expired_title'),
          message: LanguageManager.t('session_expired_desc'),
          onPressed: () {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        );
        return;
      }

      // Обработка временной недоступности сервиса (HTTP 503 / SERVICE_UNAVAILABLE)
      if (error.response?.statusCode == 503 ||
          code == 'SERVICE_UNAVAILABLE' ||
          (data is Map && data['status'] == 'SERVICE_UNAVAILABLE')) {
        final customMsg = (data is Map && data['message'] != null && data['message'].toString().isNotEmpty)
            ? data['message'].toString()
            : null;
        AppAlerts.showServiceUnavailableDialog(
          context,
          message: customMsg,
        );
        return;
      }
    }

    AppAlerts.error(context, message, title: title);
  }

  /// Обрабатывает исключения Dio и возвращает локализованное сообщение.
  static String _handleDioError(DioException error) {
    String message = LanguageManager.t('server_error_general');

    if (error.response != null) {
      final data = error.response?.data;
      
      if (data is Map) {
        // Извлечение сообщения из унифицированного контракта ErrorResponse
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          message = data['message'].toString();
        } else if (data['code'] == 'SERVICE_UNAVAILABLE' ||
            data['status'] == 'SERVICE_UNAVAILABLE' ||
            error.response?.statusCode == 503) {
          message = LanguageManager.t('http_503');
        }

        // Обработка детальных ошибок валидации (VALIDATION_ERROR)
        final String? code = data['code'];
        if (code == 'VALIDATION_ERROR' && data['details']?['fields'] != null) {
          try {
            final fields = data['details']['fields'] as Map;
            if (fields.isNotEmpty) {
              final firstError = fields.values.first;
              message = firstError.toString();
            }
          } catch (_) {}
        }
      } else {
        // Резервный механизм на основе HTTP статус-кодов
        switch (error.response?.statusCode) {
          case 400: message = LanguageManager.t('http_400'); break;
          case 401: message = LanguageManager.t('http_401'); break;
          case 403: message = LanguageManager.t('http_403'); break;
          case 404: message = LanguageManager.t('http_404'); break;
          case 500: message = LanguageManager.t('http_500'); break;
          case 503: message = LanguageManager.t('http_503'); break;
          default: message = '${LanguageManager.t('server_error_code')}: ${error.response?.statusCode}';
        }
      }
    } else {
      // Ошибки транспортного уровня (сеть, таймауты)
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          message = LanguageManager.t('err_connection_timeout');
          break;
        case DioExceptionType.sendTimeout:
          message = LanguageManager.t('err_send_timeout');
          break;
        case DioExceptionType.receiveTimeout:
          message = LanguageManager.t('err_receive_timeout');
          break;
        case DioExceptionType.connectionError:
          message = LanguageManager.t('err_connection_error');
          break;
        default:
          message = LanguageManager.t('err_network_default');
      }
    }

    return message;
  }
}
