import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Единая точка конфигурации обращений к бэкенду.
///
/// Адрес сервера не зашит в код: он читается из `.env` (ключ [API_BASE_URL]),
/// чтобы в git не попадали окружения конкретных разработчиков/стендов и
/// продакшен-домен. Если `.env` не загружен (например, файл не создан из
/// `.env.example`), используется адрес локального бэкенда для эмулятора
/// Android — приложение всё равно можно запустить без дополнительной настройки.
class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? _defaultBaseUrl;

  // Пути эндпоинтов — это не секреты, а часть контракта с бэкендом
  // (см. OpenAPI-спецификацию FastAPI), поэтому они остаются константами.

  // Авторизация
  static const String register = '/auth/register';
  static const String login = '/auth/login';

  // Транзакции
  static const String transactions = '/transactions/'; // GET, POST
  // Для удаления/обновления конкретной записи нужно добавить ID:
  // /transactions/{transaction_id}

  // Бюджеты
  static const String budgets = '/budgets/'; // GET, POST

  // AI-инсайты
  static const String insights = '/insights/'; // GET
}
