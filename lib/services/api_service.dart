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
import 'pending_deletions_store.dart';
import 'dart:async';

/// Клиент для работы с API бэкенда.
class ApiService {
  final _storage = const FlutterSecureStorage();
  final StreamController<bool> _authStream = StreamController.broadcast();
  Stream<bool> get authStream => _authStream.stream;

  Future<void> _handleSessionExpired() async {
    await clearAllUserData();
    _authStream.add(false);
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 &&
            e.requestOptions.path != ApiConfig.refreshToken) {
          if (_refreshToken != null) {
            if (kDebugMode) debugPrint('[ApiService] Token expired, attempting refresh...');
            try {
              final refreshResponse = await _dio.post(
                ApiConfig.refreshToken,
                data: {'refresh_token': _refreshToken},
              );

              final newAccess = refreshResponse.data['data']['access_token'];
              final newRefresh = refreshResponse.data['data']['refresh_token'];

              await setTokens(newAccess, newRefresh);
              if (kDebugMode) debugPrint('[ApiService] Token refreshed successfully');

              final options = e.requestOptions;
              options.headers['Authorization'] = 'Bearer $newAccess';
              return handler.resolve(await _dio.fetch(options));
            } catch (err) {
              if (kDebugMode) debugPrint('[ApiService] Token refresh failed: $err');
              await _handleSessionExpired();
              return handler.reject(e);
            }
          } else {
            if (kDebugMode) debugPrint('[ApiService] No refresh token available');
            await _handleSessionExpired();
          }
        }
        return handler.next(e);
      },
    ));

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
  String? _refreshToken;
  String? _userName;
  String? _email;

  String? get userName => _userName;
  String? get email => _email;

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    _userName = await _storage.read(key: 'auth_user');
    _email = await _storage.read(key: 'auth_email');
  }

  /// Сохраняет токены авторизации.
  Future<void> setTokens(String? token, String? refresh) async {
    _token = token;
    _refreshToken = refresh;

    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'refresh_token', value: refresh);
    } else {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'refresh_token');
    }
  }

  Future<void> setUserName(String? userName) async {
    if (userName != null) {
      _userName = userName;
      await _storage.write(key: 'auth_user', value: userName);
    }
  }

  Future<void> setUserEmail(String? email) async {
    if (email != null) {
      _email = email;
      await _storage.write(key: 'auth_email', value: email);
    }
  }

  /// Очищает все пользовательские данные авторизации.
  Future<void> clearAllUserData() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'auth_user');
    await _storage.delete(key: 'auth_email');

    _token = null;
    _refreshToken = null;
    _userName = null;
    _email = null;
  }

  bool get isAuthenticated => _token != null;

  Options _authOptions([String? token]) {
    final effectiveToken = token ?? _token;

    return Options(
      headers: {
        if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
      },
    );
  }

  /// Регистрация нового пользователя.
  Future<RegisterModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final RegisterModel registerResponse;

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
      if (kDebugMode) {
        debugPrint('[ApiService] Register error: ${e.response?.data ?? e.message}');
      }
      rethrow;
    }

    try {
      await login(email: registerResponse.email, password: password);

      return registerResponse;
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Login after register error: $e');
      rethrow;
    }
  }

  /// Вход пользователя.
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
      final refreshToken = data?['refresh_token'] as String?;

      if (token == null || refreshToken == null) {
        throw Exception('Сервер не вернул токены');
      }

      await setTokens(token, refreshToken);
      await setUserEmail(email);
      await fetchAndSaveUserProfile();

      return LoginResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiService] Login error: ${e.response?.data ?? e.message}');
      }
      rethrow;
    }
  }

  /// Получение и сохранение профиля текущего пользователя.
  Future<void> fetchAndSaveUserProfile() async {
    try {
      final response = await _dio.get(
        ApiConfig.me,
        options: _authOptions(),
      );

      final userProfile = AuthMeResponseModel.fromJson(response.data);

      await setUserName(userProfile.userName);
      await setUserEmail(userProfile.userEmail);

      if (kDebugMode) {
        debugPrint('[ApiService] Profile updated for: ${userProfile.userName}');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiService] Fetch profile error: ${e.response?.data ?? e.message}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Profile parse error: $e');
    }
  }

  /// Выход из аккаунта.
  Future<LogoutResponseModel> logout() async {
    if (_token == null) {
      if (kDebugMode) debugPrint('[ApiService] Logout attempted without token');
      return LogoutResponseModel(status: 'error', message: 'Не авторизован');
    }

    try {
      final response = await _dio.post(
        ApiConfig.logout,
        options: _authOptions(),
      );

      final logoutResponse = LogoutResponseModel.fromJson(response.data);

      if (kDebugMode) debugPrint('[ApiService] Logout success: ${logoutResponse.message}');
      return logoutResponse;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiService] Logout error: ${e.response?.data ?? e.message}');
      }
      rethrow;
    } finally {
      await clearAllUserData();
    }
  }

  Future<void> performLogout() async {
    await clearAllUserData();
    _authStream.add(false);
  }

  /// Получить транзакции.
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final response = await _dio.get(
        ApiConfig.transactions,
        options: _authOptions(),
      );

      final List<dynamic> list = response.data['data'];
      return list.map((json) => TransactionModel.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Get transactions error: $e');
      rethrow;
    }
  }

  /// Создать транзакцию.
  Future<TransactionModel> createTransaction(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        ApiConfig.transactions,
        data: data,
        options: _authOptions(),
      );

      return TransactionModel.fromJson(response.data['data']);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Create transaction error: $e');
      rethrow;
    }
  }

  /// Удалить транзакцию с сервера.
  Future<void> deleteTransaction(String id, [String? token]) async {
    try {
      await _dio.delete(
        '${ApiConfig.transactions}$id',
        options: _authOptions(token),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Delete transaction error: $e');
      rethrow;
    }
  }

  /// Удаляет транзакцию локально и на сервере.
  Future<void> deleteTransactionEverywhere(Transaction transaction) async {
    final serverId = transaction.serverId;
    LocalDbService.instance.deleteTransaction(transaction.localId);

    if (serverId == null) return;

    if (!isAuthenticated) {
      await PendingDeletionsStore.instance.addTransaction(serverId);
      return;
    }

    try {
      await deleteTransaction(serverId);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Server delete failed, deferring: $e');
      await PendingDeletionsStore.instance.addTransaction(serverId);
    }
  }

  /// Получить бюджеты.
  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    try {
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
      if (kDebugMode) debugPrint('[ApiService] Get budgets error: $e');
      rethrow;
    }
  }

  /// Создать бюджет.
  Future<BudgetModel> createBudget(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        ApiConfig.budgets,
        data: data,
        options: _authOptions(),
      );

      return BudgetModel.fromJson(response.data['data']);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Create budget error: $e');
      rethrow;
    }
  }

  /// Обновить или создать бюджет.
  Future<BudgetModel> updateBudget(Map<String, dynamic> data) async {
    // В данном API создание и обновление бюджета происходит через один и тот же POST эндпоинт.
    return createBudget(data);
  }

  /// Удалить бюджет с сервера по ID.
  Future<void> deleteBudget(String id, [String? token]) async {
    try {
      await _dio.delete(
        '${ApiConfig.budgets}$id',
        options: _authOptions(token),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Delete budget error: $e');
      rethrow;
    }
  }

  /// Удалить бюджет по категории и периоду.
  Future<void> deleteBudgetByPeriod(
    String category,
    int month,
    int year, [
    String? token,
  ]) async {
    try {
      await _dio.delete(
        '${ApiConfig.budgets}category/$category/$month/$year',
        options: _authOptions(token),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Delete budget by period error: $e');
      rethrow;
    }
  }

  /// Удаляет бюджет локально и на сервере.
  Future<void> deleteBudgetEverywhere(Budget budget) async {
    final serverId = budget.serverId;
    LocalDbService.instance.deleteBudget(budget.localId);

    if (serverId == null) return;

    if (!isAuthenticated) {
      await PendingDeletionsStore.instance.addBudget(serverId);
      return;
    }

    try {
      await deleteBudget(serverId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiService] Server budget delete failed, deferring: $e');
      }
      await PendingDeletionsStore.instance.addBudget(serverId);
    }
  }

  /// Получить AI-инсайты.
  Future<Map<String, dynamic>> getInsights() async {
    try {
      final response = await _dio.get(
        ApiConfig.insights,
        options: _authOptions(),
      );

      return response.data;
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Get insights error: $e');
      rethrow;
    }
  }

  /// Выгружает локальные транзакции и бюджеты на сервер.
  Future<Map<String, dynamic>> syncLocalDataToBackend([String? token]) async {
    final jwtToken = token ?? _token;
    if (jwtToken == null) throw Exception('Не авторизован');

    try {
      final localTransactions =
          LocalDbService.instance.getUnsyncedTransactions();
      final localBudgets = LocalDbService.instance.getUnsyncedBudgets();

      if (localTransactions.isEmpty && localBudgets.isEmpty) {
        return {'message': 'Нет данных для синхронизации'};
      }

      final payload = SyncModel(
        transactions: localTransactions.map((t) => t.toJson()).toList(),
        budgets: localBudgets.map((b) => b.toJson()).toList(),
      );

      final response = await _dio.post(ApiConfig.sync,
          data: payload.toJson(), options: _authOptions(jwtToken));

      final data = response.data['data'];

      if (data is Map) {
        _assignTransactionIds(localTransactions, data['synced_transactions']);
        _assignBudgetIds(localBudgets, data['synced_budgets']);
      }

      if (kDebugMode) debugPrint('[ApiService] Sync local -> backend success');
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Sync error: ${e.response?.statusCode}');
      throw Exception('Ошибка синхронизации: ${e.response?.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Sync unexpected error: $e');
      rethrow;
    }
  }

  /// Загружает транзакции и бюджеты пользователя с сервера в локальную базу.
  Future<Map<String, dynamic>> syncBackendDataToLocal([String? token]) async {
    final jwtToken = token ?? _token;
    if (jwtToken == null) throw Exception('Не авторизован');

    try {
      final remoteTransactions = await _fetchRemoteTransactions(jwtToken);
      final remoteBudgets = await _fetchRemoteBudgets(jwtToken);

      final removedTransactions =
          LocalDbService.instance.reconcileTransactions(remoteTransactions);
      final removedBudgets =
          LocalDbService.instance.reconcileBudgets(remoteBudgets);

      if (kDebugMode) {
        debugPrint(
            '[ApiService] Sync backend -> local: '
            'T(${remoteTransactions.length}), B(${remoteBudgets.length}); '
            'Removed: T($removedTransactions), B($removedBudgets)');
      }

      return {
        'transactions': remoteTransactions.length,
        'budgets': remoteBudgets.length,
        'removed_transactions': removedTransactions,
        'removed_budgets': removedBudgets,
      };
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Load error: ${e.response?.statusCode}');
      throw Exception('Ошибка загрузки данных: ${e.response?.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Load unexpected error: $e');
      rethrow;
    }
  }

  /// Полная двусторонняя синхронизация.
  Future<Map<String, dynamic>> syncAll([String? token]) async {
    final jwtToken = token ?? _token;
    if (jwtToken == null) throw Exception('Не авторизован');

    final deleted = await _flushPendingDeletions(jwtToken);
    final pushed = await syncLocalDataToBackend(jwtToken);
    final pulled = await syncBackendDataToLocal(jwtToken);

    return {'deleted': deleted, 'pushed': pushed, 'pulled': pulled};
  }

  Future<int> _flushPendingDeletions(String token) async {
    final pendingTransactions = PendingDeletionsStore.instance.transactionIds;
    final pendingBudgets = PendingDeletionsStore.instance.budgetIds;

    if (pendingTransactions.isEmpty && pendingBudgets.isEmpty) return 0;

    int totalDone = 0;

    if (pendingTransactions.isNotEmpty) {
      final done = <String>[];
      for (final serverId in pendingTransactions) {
        try {
          await deleteTransaction(serverId, token);
          done.add(serverId);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            done.add(serverId);
          } else {
            if (kDebugMode) {
              debugPrint(
                  '[ApiService] Flush delete transaction $serverId failed: ${e.response?.statusCode}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '[ApiService] Flush delete transaction $serverId failed: $e');
          }
        }
      }
      await PendingDeletionsStore.instance.removeTransactions(done);
      totalDone += done.length;
    }

    if (pendingBudgets.isNotEmpty) {
      final done = <String>[];
      for (final serverId in pendingBudgets) {
        try {
          await deleteBudget(serverId, token);
          done.add(serverId);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            done.add(serverId);
          } else {
            if (kDebugMode) {
              debugPrint(
                  '[ApiService] Flush delete budget $serverId failed: ${e.response?.statusCode}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[ApiService] Flush delete budget $serverId failed: $e');
          }
        }
      }
      await PendingDeletionsStore.instance.removeBudgets(done);
      totalDone += done.length;
    }

    if (kDebugMode && totalDone > 0) {
      debugPrint('[ApiService] Flushed pending deletions: $totalDone');
    }

    return totalDone;
  }

  Future<List<Transaction>> _fetchRemoteTransactions(String token) async {
    final response = await _dio.get(
      ApiConfig.transactions,
      options: _authOptions(token),
    );

    return _asJsonList(response.data['data'])
        .map(Transaction.fromJson)
        .toList();
  }

  Future<List<Budget>> _fetchRemoteBudgets(String token) async {
    final response = await _dio.get(
      ApiConfig.budgets,
      options: _authOptions(token),
    );

    return _asJsonList(response.data['data'])
        .map(Budget.fromJson)
        .where((b) => b.isValidPeriod)
        .toList();
  }

  void _assignTransactionIds(List<Transaction> sent, dynamic remote) {
    final remoteItems = _asJsonList(remote);
    if (remoteItems.isEmpty) return;

    final synced = <Transaction>[];

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
    if (kDebugMode) {
      debugPrint('[ApiService] Assigned transaction IDs: ${synced.length}/${sent.length}');
    }
  }

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
    if (kDebugMode) {
      debugPrint('[ApiService] Assigned budget IDs: ${synced.length}/${sent.length}');
    }
  }

  List<Map<String, dynamic>> _asJsonList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

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
