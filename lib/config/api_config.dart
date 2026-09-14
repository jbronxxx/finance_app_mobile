import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Единая точка конфигурации обращений к бэкенду.
class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? _defaultBaseUrl;

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String refreshToken = '/auth/refresh';

  static const String transactions = '/transactions/';
  static const String budgets = '/budgets/';
  static const String sync = '/sync/';
  static const String insights = '/insights/';
}
