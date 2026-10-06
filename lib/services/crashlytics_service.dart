import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Заглушка отправки крашей: пишет ошибки в локальный лог.
/// Точка расширения для подключения Firebase Crashlytics.
class CrashlyticsService {
  static Future<void> init() async {
    logger.i('[CrashlyticsService] Initialized. is_debug = ${!kReleaseMode}');
  }

  static Future<void> recordError(dynamic exception, StackTrace? stack,
      {bool fatal = false}) async {
    logger.e('[CrashlyticsService] Error recorded (fatal: $fatal)',
        error: exception, stackTrace: stack);
  }
}
