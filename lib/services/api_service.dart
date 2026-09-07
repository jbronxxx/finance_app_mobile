import 'package:dio/dio.dart';
import '../main.dart'; // где лежит ваш dbService

// Модель данных для отправки (DTO)
class SyncPayload {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;

  SyncPayload({required this.transactions, required this.budgets});

  Map<String, dynamic> toJson() => {
        'transactions': transactions,
        'budgets': budgets,
      };
}

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://your-fastapi-backend.com/api/v1'));

  // Метод отправки накопленных гостевых данных после логина/регистрации
  Future<void> syncLocalDataToBackend(String jwtToken) async {
    try {
      // 1. Выгружаем всё, что накопилось в гостевом режиме локально
      final localTransactions = dbService.getAllTransactions();
      final localBudgets = dbService.getAllBudgets(); // или ваш метод получения бюджетов

      // 2. Форматируем транзакции в JSON-совместимый вид
      final transactionsJson = localTransactions.map((t) => {
            'local_id': t.localId,
            'type': t.dbType, // 'income' или 'expense'
            'category': t.dbCategory,
            'amount': t.amount,
            'date': DateTime.fromMillisecondsSinceEpoch(t.dateMilliseconds).toIso8601String(),
            'description': t.description,
          }).toList();

      // 3. Форматируем бюджеты
      final budgetsJson = localBudgets.map((b) => {
            'category': b.dbCategory,
            'limit_amount': b.limitAmount,
            'month': b.month,
            'year': b.year,
          }).toList();

      final payload = SyncPayload(
        transactions: transactionsJson,
        budgets: budgetsJson,
      );

      // 4. Отправляем на бэкенд с JWT-токеном
      await _dio.post(
        '/sync',
        data: payload.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      // Опционально: пометить локальные записи как синхронизированные, если нужно
    } catch (e) {
      print('Ошибка синхронизации: $e');
      rethrow;
    }
  }
}