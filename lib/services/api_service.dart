import 'package:dio/dio.dart';
import 'package:family_budget/models/auth_model.dart';
import 'package:family_budget/models/budget_model.dart';
import 'package:family_budget/models/local_db_models.dart';
import 'package:family_budget/models/paginated_response.dart';
import 'package:family_budget/models/sync_model.dart';
import 'package:family_budget/models/transaction_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';
import 'tracing_interceptor.dart';
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

  @visibleForTesting
  Dio get dio => _dio;

  ApiService._internal() {
    _dio.interceptors.add(TracingInterceptor());
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _token;
        if (token != null &&
            !options.headers.containsKey('Authorization') &&
            options.path != ApiConfig.refreshToken &&
            options.path != ApiConfig.login &&
            options.path != ApiConfig.register) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 &&
            e.requestOptions.path != ApiConfig.refreshToken &&
            e.requestOptions.path != ApiConfig.login) {
          final refreshToken = _refreshToken ?? await _storage.read(key: 'refresh_token');
          if (refreshToken != null && refreshToken.isNotEmpty) {
            if (kDebugMode) debugPrint('[ApiService] Token expired (401), attempting refresh...');
            try {
              final refreshResponse = await _dio.post(
                ApiConfig.refreshToken,
                data: {'refresh_token': refreshToken},
              );

              final resData = refreshResponse.data is Map
                  ? (refreshResponse.data['data'] is Map
                      ? refreshResponse.data['data'] as Map<String, dynamic>
                      : refreshResponse.data as Map<String, dynamic>)
                  : <String, dynamic>{};

              final newAccess = resData['access_token'] as String?;
              final newRefresh = resData['refresh_token'] as String? ?? refreshToken;

              if (newAccess != null && newAccess.isNotEmpty) {
                await setTokens(newAccess, newRefresh);
                if (kDebugMode) debugPrint('[ApiService] Token refreshed successfully');

                final options = e.requestOptions;
                options.headers['Authorization'] = 'Bearer $newAccess';
                return handler.resolve(await _dio.fetch(options));
              } else {
                throw Exception('Empty access token returned on refresh');
              }
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
  String? _transactionsEtag;
  String? _budgetsEtag;

  String? get userName => _userName;
  String? get email => _email;

  Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    _userName = await _storage.read(key: 'auth_user');
    _email = await _storage.read(key: 'auth_email');
    _transactionsEtag = await _storage.read(key: 'transactions_etag');
    _budgetsEtag = await _storage.read(key: 'budgets_etag');
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
    await _storage.delete(key: 'transactions_etag');
    await _storage.delete(key: 'budgets_etag');

    _token = null;
    _refreshToken = null;
    _userName = null;
    _email = null;
    _transactionsEtag = null;
    _budgetsEtag = null;
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

      _authStream.add(true); // Уведомляем об успешном входе

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

  /// Запрашивает список транзакций с бэкенда с поддержкой пагинации и фильтрации по дате.
  /// Ограничивает `limit` диапазоном от 1 до 100 и предотвращает отрицательные значения `offset`.
  Future<PaginatedResponse<TransactionModel>> getTransactions({
    int limit = 50,
    int offset = 0,
    DateTime? since,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.clamp(1, 100),
        'offset': offset < 0 ? 0 : offset,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      };

      final response = await _dio.get(
        ApiConfig.transactions,
        queryParameters: queryParams,
        options: _authOptions(),
      );

      final dynamic data = response.data is Map ? response.data['data'] : response.data;
      if (data is Map) {
        return PaginatedResponse<TransactionModel>.fromJson(
          Map<String, dynamic>.from(data),
          (item) => TransactionModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        );
      } else if (data is List) {
        final items = data
            .whereType<Map>()
            .map((json) => TransactionModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        return PaginatedResponse<TransactionModel>(
          items: items,
          total: items.length,
          limit: limit,
          offset: offset,
        );
      }

      return PaginatedResponse<TransactionModel>(
        items: const [],
        total: 0,
        limit: limit,
        offset: offset,
      );
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
  Future<Map<String, dynamic>> getInsights({CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get(
        ApiConfig.insights,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      return response.data['data'] as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Get insights error: $e');
      rethrow;
    }
  }

  /// Проверка состояния сервера (/health).
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _dio.get(ApiConfig.health);
      return response.data is Map ? (response.data as Map).cast<String, dynamic>() : {'status': 'ok'};
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Health check error: $e');
      rethrow;
    }
  }

  /// Обновление пары JWT-токенов через POST /api/v1/auth/refresh.
  Future<bool> refreshAuthTokens() async {
    final currentRefresh = _refreshToken ?? await _storage.read(key: 'refresh_token');
    if (currentRefresh == null || currentRefresh.isEmpty) {
      await _handleSessionExpired();
      return false;
    }

    try {
      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refresh_token': currentRefresh},
      );

      final resData = response.data is Map
          ? (response.data['data'] is Map
              ? response.data['data'] as Map<String, dynamic>
              : response.data as Map<String, dynamic>)
          : <String, dynamic>{};

      final newAccess = resData['access_token'] as String?;
      final newRefresh = resData['refresh_token'] as String? ?? currentRefresh;

      if (newAccess != null && newAccess.isNotEmpty) {
        await setTokens(newAccess, newRefresh);
        return true;
      } else {
        await _handleSessionExpired();
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] refreshAuthTokens error: $e');
      await _handleSessionExpired();
      return false;
    }
  }

  /// Выгружает локальные транзакции и бюджеты на сервер (включая удаленные офлайн бюджеты).
  Future<Map<String, dynamic>> syncLocalDataToBackend([String? token]) async {
    final jwtToken = token ?? _token;
    if (jwtToken == null) throw Exception('Не авторизован');

    try {
      final localTransactions =
          LocalDbService.instance.getUnsyncedTransactions();
      final localBudgets = LocalDbService.instance.getUnsyncedBudgets();
      final pendingBudgets = PendingDeletionsStore.instance.budgetIds.toList();
      final pendingTransactions = PendingDeletionsStore.instance.transactionIds.toList();

      if (localTransactions.isEmpty &&
          localBudgets.isEmpty &&
          pendingBudgets.isEmpty &&
          pendingTransactions.isEmpty) {
        return {'message': 'Нет данных для синхронизации'};
      }

      // Формируем список бюджетов с поддержкой флага is_deleted: true для удаленных офлайн
      final budgetsPayload = <Map<String, dynamic>>[];
      for (final b in localBudgets) {
        budgetsPayload.add(b.toJson());
      }
      for (final budgetId in pendingBudgets) {
        budgetsPayload.add({
          'id': budgetId,
          'is_deleted': true,
        });
      }

      final payload = SyncModel(
        transactions: localTransactions.map((t) => t.toJson()).toList(),
        budgets: budgetsPayload,
        deletedBudgetIds: pendingBudgets.isNotEmpty ? pendingBudgets : null,
        deletedTransactionIds: pendingTransactions.isNotEmpty ? pendingTransactions : null,
      );

      final response = await _dio.post(
        ApiConfig.sync,
        data: payload.toJson(),
        options: _authOptions(jwtToken),
      );

      final data = response.data['data'];

      if (data is Map) {
        _assignTransactionIds(localTransactions, data['synced_transactions']);
        _assignBudgetIds(localBudgets, data['synced_budgets']);
      }

      if (pendingBudgets.isNotEmpty) {
        await PendingDeletionsStore.instance.removeBudgets(pendingBudgets);
      }
      if (pendingTransactions.isNotEmpty) {
        await PendingDeletionsStore.instance.removeTransactions(pendingTransactions);
      }

      if (kDebugMode) debugPrint('[ApiService] Sync local -> backend success');
      return data is Map ? data.cast<String, dynamic>() : response.data;
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

      int removedTransactions = 0;
      int transLength = 0;
      if (remoteTransactions != null) {
        removedTransactions =
            LocalDbService.instance.reconcileTransactions(remoteTransactions);
        transLength = remoteTransactions.length;
      } else {
        if (kDebugMode) debugPrint('[ApiService] Transactions not modified (304). Skipping reconciliation.');
        transLength = LocalDbService.instance.getAllTransactions().length;
      }

      int removedBudgets = 0;
      int budgetsLength = 0;
      if (remoteBudgets != null) {
        removedBudgets =
            LocalDbService.instance.reconcileBudgets(remoteBudgets);
        budgetsLength = remoteBudgets.length;
      } else {
        if (kDebugMode) debugPrint('[ApiService] Budgets not modified (304). Skipping reconciliation.');
        budgetsLength = LocalDbService.instance.getAllBudgets().length;
      }

      if (kDebugMode) {
        debugPrint(
            '[ApiService] Sync backend -> local: '
            'T($transLength), B($budgetsLength); '
            'Removed: T($removedTransactions), B($removedBudgets)');
      }

      return {
        'transactions': transLength,
        'budgets': budgetsLength,
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

  Future<List<Transaction>?> _fetchRemoteTransactions(String token, {DateTime? since}) async {
    final options = _authOptions(token);
    options.validateStatus = (status) => status != null && ((status >= 200 && status < 300) || status == 304);
    if (_transactionsEtag != null) {
      options.headers?['If-None-Match'] = _transactionsEtag;
    }

    const pageSize = 100;
    int currentOffset = 0;
    final allTransactions = <Transaction>[];

    final firstResponse = await _dio.get(
      ApiConfig.transactions,
      queryParameters: {
        'limit': pageSize,
        'offset': currentOffset,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
      options: options,
    );

    if (firstResponse.statusCode == 304) {
      return null;
    }

    final newEtag = firstResponse.headers.value('etag');
    if (newEtag != null) {
      _transactionsEtag = newEtag;
      await _storage.write(key: 'transactions_etag', value: newEtag);
    }

    final firstData = firstResponse.data is Map ? firstResponse.data['data'] : null;
    final firstItems = _asJsonList(firstData);
    allTransactions.addAll(firstItems.map(Transaction.fromJson));

    if (firstData is Map && firstData['total'] is num) {
      final total = (firstData['total'] as num).toInt();
      currentOffset += firstItems.length;

      while (currentOffset < total) {
        final nextResponse = await _dio.get(
          ApiConfig.transactions,
          queryParameters: {
            'limit': pageSize,
            'offset': currentOffset,
            if (since != null) 'since': since.toUtc().toIso8601String(),
          },
          options: _authOptions(token),
        );

        final nextData = nextResponse.data is Map ? nextResponse.data['data'] : null;
        final nextItems = _asJsonList(nextData);
        if (nextItems.isEmpty) break;

        allTransactions.addAll(nextItems.map(Transaction.fromJson));
        currentOffset += nextItems.length;
      }
    }

    return allTransactions;
  }

  Future<List<Budget>?> _fetchRemoteBudgets(String token) async {
    final options = _authOptions(token);
    options.validateStatus = (status) =>
        status != null && ((status >= 200 && status < 300) || status == 304);

    if (_budgetsEtag != null) {
      options.headers?['If-None-Match'] = _budgetsEtag;
    }

    final response = await _dio.get(
      ApiConfig.budgets,
      options: options,
    );

    if (response.statusCode == 304) {
      return null;
    }

    final newEtag = response.headers.value('etag');
    if (newEtag != null) {
      _budgetsEtag = newEtag;
      await _storage.write(key: 'budgets_etag', value: newEtag);
    }

    return _asJsonList(response.data['data'])
        .map(Budget.fromJson)
        .where((b) => b.isValidPeriod)
        .toList();
  }

  void _assignTransactionIds(List<Transaction> sent, dynamic remote) {
    final remoteItems = _asJsonList(remote);
    if (remoteItems.isEmpty) {
      final synced = <Transaction>[];
      for (final local in sent) {
        if (local.isModified) {
          local.isModified = false;
          synced.add(local);
        }
      }
      if (synced.isNotEmpty) {
        LocalDbService.instance.putTransactions(synced);
      }
      return;
    }

    final synced = <Transaction>[];

    if (remoteItems.length == sent.length) {
      for (var i = 0; i < sent.length; i++) {
        final id = remoteItems[i]['id'];

        if (id is String) {
          sent[i].serverId = id;
          sent[i].isModified = false;
          synced.add(sent[i]);
        }
      }
    } else {
      final byId = <String, Map<String, dynamic>>{};
      final byKey = <String, Map<String, dynamic>>{};

      for (final json in remoteItems) {
        final id = json['id'];
        if (id is String) {
          byId[id] = json;
        }
        byKey[_remoteTransactionKey(json)] = json;
      }
      for (final local in sent) {
        if (local.serverId != null && byId.containsKey(local.serverId)) {
          local.isModified = false;
          synced.add(local);
        } else {
          final matchedJson = byKey[_localTransactionKey(local)];
          final id = matchedJson?['id'];

          if (id is String) {
            local.serverId = id;
            local.isModified = false;
            synced.add(local);
          } else if (local.serverId != null) {
            local.isModified = false;
            synced.add(local);
          }
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
    if (remoteItems.isEmpty) {
      final synced = <Budget>[];
      for (final local in sent) {
        if (local.isModified) {
          local.isModified = false;
          synced.add(local);
        }
      }
      if (synced.isNotEmpty) {
        LocalDbService.instance.putBudgets(synced);
      }
      return;
    }

    final synced = <Budget>[];

    if (remoteItems.length == sent.length) {
      for (var i = 0; i < sent.length; i++) {
        final id = remoteItems[i]['id'];

        if (id is String) {
          sent[i].serverId = id;
          sent[i].isModified = false;
          synced.add(sent[i]);
        }
      }
    } else {
      final byId = <String, Map<String, dynamic>>{};
      final byKey = <String, Map<String, dynamic>>{};

      for (final json in remoteItems) {
        final id = json['id'];
        if (id is String) {
          byId[id] = json;
        }
        byKey['${json['category']}|${json['month']}|${json['year']}'] = json;
      }
      for (final local in sent) {
        if (local.serverId != null && byId.containsKey(local.serverId)) {
          local.isModified = false;
          synced.add(local);
        } else {
          final matchedJson =
              byKey['${local.category.name}|${local.month}|${local.year}'];
          final id = matchedJson?['id'];

          if (id is String) {
            local.serverId = id;
            local.isModified = false;
            synced.add(local);
          } else if (local.serverId != null) {
            local.isModified = false;
            synced.add(local);
          }
        }
      }
    }

    LocalDbService.instance.putBudgets(synced);
    if (kDebugMode) {
      debugPrint('[ApiService] Assigned budget IDs: ${synced.length}/${sent.length}');
    }
  }

  List<Map<String, dynamic>> _asJsonList(dynamic value) {
    if (value is Map && value['items'] is List) {
      return (value['items'] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  String _remoteTransactionKey(Map<String, dynamic> json) {
    final date = parseServerDate(json['date']) ??
        DateTime.parse(json['date'] as String).toLocal();

    return '${parseAmount(json['amount'])}|${json['category']}|'
        '${json['type']}|${date.millisecondsSinceEpoch}';
  }

  String _localTransactionKey(Transaction t) {
    return '${t.amount}|${t.category.name}|${t.type.name}|'
        '${t.date.millisecondsSinceEpoch}';
  }
}
