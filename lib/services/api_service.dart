import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'local_db_service.dart';

/// DTO для отправки накопленных гостевых данных на бэкенд одним запросом.
class SyncPayload {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;

  SyncPayload({required this.transactions, required this.budgets});

  Map<String, dynamic> toJson() => {
        'transactions': transactions,
        'budgets': budgets,
      };
}

/// Клиент для общения с FastAPI-бэкендом.
///
/// На данный момент используется только для отправки гостевых (офлайн)
/// данных после входа/регистрации — сама авторизация в UI (см. AuthScreen)
/// пока не подключена к реальному бэкенду и работает как заглушка. Экран
/// профиля тоже лишь имитирует синхронизацию. Это осознанно оставлено как
/// точка расширения: когда бэкенд будет готов принимать запросы, именно
/// через [ApiService] и [ApiConfig.baseUrl] пойдёт реальный трафик.
class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  /// Выгружает все локальные транзакции и бюджеты на сервер по эндпоинту
  /// `/sync`, авторизуясь переданным JWT-токеном. Используется один раз
  /// сразу после успешного входа/регистрации, чтобы не потерять данные,
  /// накопленные в гостевом режиме.
  Future<void> syncLocalDataToBackend(String jwtToken) async {
    try {
      final localTransactions = LocalDbService.instance.getAllTransactions();
      final localBudgets = LocalDbService.instance.getAllBudgets();

      final transactionsJson = localTransactions
          .map((t) => {
                'local_id': t.localId,
                'type': t.dbType, // 'income' или 'expense'
                'category': t.dbCategory,
                'amount': t.amount,
                'date': t.date.toIso8601String(),
                'description': t.description,
              })
          .toList();

      final budgetsJson = localBudgets
          .map((b) => {
                'category': b.dbCategory,
                'limit_amount': b.limitAmount,
                'month': b.month,
                'year': b.year,
              })
          .toList();

      final payload = SyncPayload(
        transactions: transactionsJson,
        budgets: budgetsJson,
      );

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
    } catch (e) {
      // TODO: заменить debugPrint на нормальное логирование, когда появится
      // единый механизм логов (или пакет вроде logger/logging).
      debugPrint('Ошибка синхронизации: $e');
      rethrow;
    }
  }
}
