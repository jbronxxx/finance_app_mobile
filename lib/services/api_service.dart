import 'package:dio/dio.dart';
import 'package:family_budget/models/auth_model.dart';
import 'package:family_budget/models/budget_model.dart';
import 'package:family_budget/models/local_db_models.dart';
import 'package:family_budget/models/sync_model.dart';
import 'package:family_budget/models/transaction_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'local_db_service.dart';

/// Клиент для общения с FastAPI-бэкендом.
///
/// На данный момент используется только для отправки гостевых (офлайн)
/// данных после входа/регистрации — сама авторизация в UI (см. AuthScreen)
/// пока не подключена к реальному бэкенду и работает как заглушка. Экран
/// профиля тоже лишь имитирует синхронизацию. Это осознанно оставлено как
/// точка расширения: когда бэкенд будет готов принимать запросы, именно
/// через [ApiService] и [ApiConfig.baseUrl] пойдёт реальный трафик.
class ApiService {
  final _storage = const FlutterSecureStorage();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  // Синглтон
  ApiService._internal() {
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ));
    }
  }

  static final ApiService instance = ApiService._internal();

  String? _token;
  String? _userName;
  String? _email;

  String? get userName => _userName;
  String? get email => _email;

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    _userName = await _storage.read(key: 'auth_user');
    _email = await _storage.read(key: 'auth_email');
  }

  /// Сохраняет токен в памяти и в защищённом хранилище.
  ///
  /// `_token` присваивается ДО записи в хранилище: если сначала ждать
  /// `_storage.write`, то запросы, отправленные в этом промежутке, уходят
  /// без заголовка Authorization (именно так `/auth/me` уходил
  /// неавторизованным сразу после логина).
  ///
  /// `setToken(null)` — это выход из аккаунта, поэтому токен удаляется и из
  /// хранилища, иначе [init] поднимет его обратно при следующем запуске.
  Future<void> setToken(String? token) async {
    _token = token;

    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
    } else {
      await _storage.delete(key: 'auth_token');
    }
  }

  Future<void> setUserName(String? userName) async {
    if (userName != null) {
      _userName = userName;
      await _storage.write(key: 'auth_user', value: userName);
    }
  }

  /// Получить имя пользователя и email из защищённого хранилища
  /// и установить их для последующих операций
  Future<void> setUserEmail(String? email) async {
    if (email != null) {
      _email = email;
      await _storage.write(key: 'auth_email', value: email);
    }
  }

  Future<void> clearAllUserData() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_user');
    await _storage.delete(key: 'auth_email');

    _token = null;
    _userName = null;
    _email = null;
  }

  bool get isAuthenticated => _token != null;

  /// Хелпер для получения заголовков с авторизацией
  Options _authOptions() {
    return Options(
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
  }

  /// Регистрация (POST /auth/register)
  Future<RegisterModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final RegisterModel registerResponse;

    // Сначала регистрируем пользователя, затем сразу логинимся, чтобы получить токен
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );

      registerResponse = RegisterModel.fromJson(response.data);
      await setUserName(registerResponse.name);
      await setUserEmail(registerResponse.email);
    } on DioException catch (e) {
      debugPrint('Ошибка регистрации: ${e.response?.data ?? e.message}');
      rethrow;
    }

    // После успешной регистрации сразу логинимся, чтобы получить токен.
    // Пароль берём из формы: бэкенд его в ответе не возвращает, а login()
    // сам сохранит токен и подтянет профиль через /auth/me.
    try {
      await login(email: registerResponse.email, password: password);

      return registerResponse;
    } catch (e) {
      debugPrint('Ошибка входа после регистрации: $e');
      rethrow;
    }
  }

  /// Вход (POST /auth/login)
  Future<LoginResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data['data'];
      final token = data?['access_token'] as String?;

      if (token == null) {
        throw Exception('Сервер не вернул access_token');
      }

      // Токен сохраняем с await: следующий запрос (/auth/me) должен уйти уже
      // с заголовком Authorization.
      await setToken(token);

      // Email известен из формы входа — подставляем сразу, чтобы профиль было
      // чем заполнить, даже если /auth/me не ответит.
      await setUserEmail(email);
      await fetchAndSaveUserProfile();

      // Модели разбирают полный ответ (`json['data'][...]`), поэтому сюда
      // передаём response.data, а не уже развёрнутый data.
      return LoginResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('Ошибка входа: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  Future<void> fetchAndSaveUserProfile() async {
    try {
      final response = await _dio.get(
        ApiConfig.me,
        options: _authOptions(),
      );

      final userProfile = AuthMeResponseModel.fromJson(response.data);

      await setUserName(userProfile.userName);
      await setUserEmail(userProfile.userEmail);

      debugPrint('Профиль пользователя обновлен: ${userProfile.userName}');
    } on DioException catch (e) {
      debugPrint('Ошибка при получении профиля: ${e.response?.data ?? e.message}');
    } catch (e) {
      // Профиль — не критичная часть входа: при неожиданном формате ответа
      // логин не роняем, в UI останется email, сохранённый при входе.
      debugPrint('Не удалось разобрать профиль пользователя: $e');
    }
  }

  /// Выход (POST /auth/logout)
  /// После выхода токен удаляется из памяти, и последующие запросы будут без авторизации.
  Future<LogoutResponseModel> logout() async {
    if (_token == null) {
      debugPrint('Попытка выхода без авторизации');
      return LogoutResponseModel(status: 'error', message: 'Не авторизован');
    }

    // Отправляем запрос на выход, чтобы сервер мог инвалидировать токен
    try {
      final respone = await _dio.post(
        ApiConfig.logout,
        options: _authOptions(),
      );

      final logoutResponse = LogoutResponseModel.fromJson(respone.data);

      debugPrint('Выход успешен: ${logoutResponse.message}');
      return logoutResponse;
    } on DioException catch (e) {
      debugPrint('Ошибка выхода: ${e.response?.data ?? e.message}');
      rethrow;
    } finally {
      // Очищаем пользовательские данные из защищённого хранилища и памяти, чтобы последующие запросы были без авторизации
      await clearAllUserData();
    }
  }

  /// Получить транзакции (GET /transactions/)
  Future<List<TransactionModel>> getTransactions() async {
    try {
      // Отправляем GET-запрос на эндпоинт /transactions/ с авторизацией
      final response = await _dio.get(
        ApiConfig.transactions,
        options: _authOptions(),
      );

      final List<dynamic> list = response.data['data'];
      return list.map((json) => TransactionModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Ошибка получения транзакций: $e');
      rethrow;
    }
  }

  /// Создать транзакцию (POST /transactions/)
  Future<TransactionModel> createTransaction(Map<String, dynamic> data) async {
    try {
      // Отправляем POST-запрос на эндпоинт /transactions/ с авторизацией и данными транзакции
      final response = await _dio.post(
        ApiConfig.transactions,
        data: data,
        options: _authOptions(),
      );

      return TransactionModel.fromJson(response.data['data']);
    } catch (e) {
      debugPrint('Ошибка создания транзакции: $e');
      rethrow;
    }
  }

  /// Удалить транзакцию (DELETE /transactions/{id})
  Future<void> deleteTransaction(String id) async {
    try {
      // Отправляем DELETE-запрос на эндпоинт /transactions/{id} с авторизацией и id транзакции
      await _dio.delete(
        '${ApiConfig.transactions}$id',
        options: _authOptions(),
      );
    } catch (e) {
      debugPrint('Ошибка удаления транзакции: $e');
      rethrow;
    }
  }

  /// Получить бюджеты (GET /budgets/)
  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    try {
      // Отправляем GET-запрос на эндпоинт /budgets/ с авторизацией и опциональными параметрами month и year
      final response = await _dio.get(
        ApiConfig.budgets,
        queryParameters: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        },
        options: _authOptions(),
      );

      final List<dynamic> list = response.data['data'];
      return list.map((json) => BudgetModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Ошибка получения бюджетов: $e');
      rethrow;
    }
  }

  /// Установить бюджет (POST /budgets/)
  Future<BudgetModel> createBudget(Map<String, dynamic> data) async {
    try {
      // Отправляем POST-запрос на эндпоинт /budgets/ с авторизацией и данными бюджета
      final response = await _dio.post(
        ApiConfig.budgets,
        data: data,
        options: _authOptions(),
      );

      return BudgetModel.fromJson(response.data['data']);
    } catch (e) {
      debugPrint('Ошибка создания бюджета: $e');
      rethrow;
    }
  }

  /// Получить AI-инсайты (GET /insights/)
  Future<Map<String, dynamic>> getInsights() async {
    try {
      // Отправляем GET-запрос на эндпоинт /insights/ с авторизацией
      final response = await _dio.get(
        ApiConfig.insights,
        options: _authOptions(),
      );

      return response.data;
    } catch (e) {
      debugPrint('Ошибка получения инсайтов: $e');
      rethrow;
    }
  }

  /// Выгружает на сервер локальные транзакции и бюджеты, у которых ещё нет
  /// `serverId`, по эндпоинту `/sync`, авторизуясь переданным JWT-токеном.
  /// Вызывается после входа/регистрации (чтобы не потерять данные, накопленные
  /// в гостевом режиме) и по кнопке в профиле.
  ///
  /// Локальная база НЕ очищается: вместо этого выгруженным записям
  /// проставляются полученные от сервера UUID, поэтому повторный вызов
  /// ничего не отправляет заново и дубликаты на сервере не появляются.
  Future<Map<String, dynamic>> syncLocalDataToBackend([String? token]) async {
    final jwtToken = token ?? _token;
    if (jwtToken == null) throw Exception('Не авторизован');

    try {
      // Получаем несинхронизированные транзакции и бюджеты из локального хранилища
      final localTransactions =
          LocalDbService.instance.getUnsyncedTransactions();
      final localBudgets = LocalDbService.instance.getUnsyncedBudgets();

      if (localTransactions.isEmpty && localBudgets.isEmpty) {
        return {'message': 'Нет данных для синхронизации'};
      }

      // Создаем объект SyncModel, который содержит данные
      final payload = SyncModel(
        transactions: localTransactions.map((t) => t.toJson()).toList(),
        budgets: localBudgets.map((b) => b.toJson()).toList(),
      );

      // Отправляем POST-запрос на эндпоинт /sync с авторизацией и данными локальных транзакций и бюджетов
      final response = await _dio.post(ApiConfig.sync,
          data: payload.toJson(), options: _authOptions());

      // Ответ обязательно разбираем: сервер возвращает созданные записи с
      // их UUID, и эти UUID нужно записать в локальную базу. Иначе записи
      // останутся с `serverId == null`, попадут в следующую выгрузку и
      // продублируются на сервере (у транзакций нет естественного ключа,
      // по которому бэкенд мог бы сделать upsert, — в отличие от бюджетов
      // с их `category + month + year`).
      final data = response.data['data'];

      if (data is Map) {
        _assignTransactionIds(localTransactions, data['synced_transactions']);
        _assignBudgetIds(localBudgets, data['synced_budgets']);
      }

      debugPrint('Синхронизация успешна');
      return response.data;
    } on DioException catch (e) {
      debugPrint('Ошибка синхронизации: ${e.response?.statusCode}');
      throw Exception('Ошибка синхронизации: ${e.response?.statusCode}');
    } catch (e) {
      debugPrint('Произошла непредвиденная ошибка: $e');
      rethrow;
    }
  }

  /// Проставляет локальным транзакциям `serverId` из ответа `/sync/` и
  /// сохраняет их обратно в ObjectBox.
  ///
  /// Бэкенд возвращает записи в том же порядке, в котором они были
  /// отправлены, поэтому основной путь — сопоставление по индексу. Если
  /// количество не совпало (сервер принял не всё), падаем на сопоставление
  /// по содержимому записи.
  void _assignTransactionIds(List<Transaction> sent, dynamic remote) {
    final remoteItems = _asJsonList(remote);
    if (remoteItems.isEmpty) return;

    final synced = <Transaction>[];

    // Проверяем, что количество записей совпал
    if (remoteItems.length == sent.length) {
      for (var i = 0; i < sent.length; i++) {
        final id = remoteItems[i]['id'];

        if (id is String) {
          sent[i].serverId = id;
          synced.add(sent[i]);
        }
      }
    } else {
      final byKey = <String, Map<String, dynamic>>{};

      for (final json in remoteItems) {
        byKey[_remoteTransactionKey(json)] = json;
      }
      for (final local in sent) {
        final id = byKey[_localTransactionKey(local)]?['id'];

        if (id is String) {
          local.serverId = id;
          synced.add(local);
        }
      }
    }

    LocalDbService.instance.putTransactions(synced);
    debugPrint(
        'Синхронизировано транзакций: ${synced.length} из ${sent.length}');
  }

  /// То же для бюджетов — см. [_assignTransactionIds].
  void _assignBudgetIds(List<Budget> sent, dynamic remote) {
    final remoteItems = _asJsonList(remote);
    if (remoteItems.isEmpty) return;

    final synced = <Budget>[];

    if (remoteItems.length == sent.length) {
      for (var i = 0; i < sent.length; i++) {
        final id = remoteItems[i]['id'];

        if (id is String) {
          sent[i].serverId = id;
          synced.add(sent[i]);
        }
      }
    } else {
      final byKey = <String, Map<String, dynamic>>{};

      for (final json in remoteItems) {
        byKey['${json['category']}|${json['month']}|${json['year']}'] = json;
      }
      for (final local in sent) {
        final id =
            byKey['${local.category.name}|${local.month}|${local.year}']?['id'];

        if (id is String) {
          local.serverId = id;
          synced.add(local);
        }
      }
    }

    LocalDbService.instance.putBudgets(synced);
    debugPrint('Синхронизировано бюджетов: ${synced.length} из ${sent.length}');
  }

  List<Map<String, dynamic>> _asJsonList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// Ключ транзакции для сопоставления «отправленное -> созданное на сервере».
  /// Дату сравниваем в миллисекундах: сервер отдаёт ISO с микросекундами
  /// (`...T20:26:49.988000`), а `DateTime.toIso8601String()` — с
  /// миллисекундами, поэтому строки напрямую не совпадут.
  String _remoteTransactionKey(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);

    return '${(json['amount'] as num).toDouble()}|${json['category']}|'
        '${json['type']}|${date.millisecondsSinceEpoch}';
  }

  String _localTransactionKey(Transaction t) {
    return '${t.amount}|${t.category.name}|${t.type.name}|'
        '${t.date.millisecondsSinceEpoch}';
  }
}
