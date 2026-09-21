import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../widgets/app_alerts.dart';

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
          title: 'Сессия истекла',
          message: 'Пожалуйста, войдите в аккаунт снова для продолжения работы.',
          onPressed: () {
            // В будущем здесь можно добавить навигацию на экран входа
          },
        );
        return;
      }
    }

    AppAlerts.error(context, message, title: title);
  }

  /// Обрабатывает исключения Dio и возвращает локализованное сообщение.
  static String _handleDioError(DioException error) {
    String message = 'Произошла ошибка при связи с сервером';

    if (error.response != null) {
      final data = error.response?.data;
      
      if (data is Map) {
        // Извлечение сообщения из унифицированного контракта ErrorResponse
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          message = data['message'];
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
          case 400: message = 'Некорректный запрос'; break;
          case 401: message = 'Необходима авторизация'; break;
          case 403: message = 'Доступ запрещен'; break;
          case 404: message = 'Ресурс не найден'; break;
          case 500: message = 'Внутренняя ошибка сервера'; break;
          default: message = 'Ошибка сервера: ${error.response?.statusCode}';
        }
      }
    } else {
      // Ошибки транспортного уровня (сеть, таймауты)
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          message = 'Превышено время ожидания соединения';
          break;
        case DioExceptionType.sendTimeout:
          message = 'Превышено время отправки данных';
          break;
        case DioExceptionType.receiveTimeout:
          message = 'Превышено время получения данных';
          break;
        case DioExceptionType.connectionError:
          message = 'Отсутствует интернет-соединение или сервер недоступен';
          break;
        default:
          message = 'Ошибка сети: проверьте подключение';
      }
    }

    return message;
  }
}
