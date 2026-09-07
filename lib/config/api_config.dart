class ApiConfig {
  // Базовый URL вашего FastAPI бэкенда. 
  // Для эмулятора Android localhost - это 10.0.2.2
  // Для iOS симулятора - это 127.0.0.1
  // В продакшене здесь будет ваш реальный домен (например, https://api.financeapp.com)
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // Эндпоинты, основанные на вашей OpenAPI спецификации
  
  // Авторизация
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  
  // Транзакции
  static const String transactions = '/transactions/'; // GET, POST
  // Для удаления нужно добавлять ID: /transactions/{transaction_id}
  
  // Бюджеты
  static const String budgets = '/budgets/'; // GET, POST
  
  // AI Инсайты
  static const String insights = '/insights/'; // GET
}