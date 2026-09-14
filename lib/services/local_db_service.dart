import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/local_db_models.dart';
import '../objectbox.g.dart'; // Генерируется автоматически: `dart run build_runner build`

/// Локальное хранилище приложения на базе ObjectBox.
///
/// Работает как singleton: инициализируется один раз в [main] через [init],
/// после чего доступ к базе идёт через [instance] — так экраны не тянут
/// зависимость на `main.dart` и не образуют циклический импорт
/// (main.dart -> screens -> main.dart), который был в предыдущей версии.
///
/// Хранит транзакции и лимиты бюджета в гостевом (офлайн) режиме; после
/// входа пользователя эти данные синхронизируются с бэкендом через
/// [ApiService].
class LocalDbService {
  static late final LocalDbService instance;

  late final Store _store;
  late final Box<Transaction> _transactionBox;
  late final Box<Budget> _budgetBox;

  LocalDbService._create(this._store) {
    _transactionBox = Box<Transaction>(_store);
    _budgetBox = Box<Budget>(_store);
  }

  /// Открывает (или создаёт) файл базы данных в директории документов
  /// приложения и инициализирует [instance]. Должен быть вызван один раз
  /// при старте приложения, до первого обращения к [instance].
  static Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, "obx-finance");
    if (kDebugMode) debugPrint('[LocalDbService] Opening store at $dbPath');
    final store = await openStore(directory: dbPath);
    instance = LocalDbService._create(store);
  }

  // --- Транзакции ---

  /// Возвращает все транзакции, отсортированные от новых к старым.
  List<Transaction> getAllTransactions() {
    final query = _transactionBox.query()
      ..order(Transaction_.dateMilliseconds, flags: Order.descending);
    final q = query.build();
    final results = q.find();
    q.close();
    return results;
  }

  /// Добавляет новую транзакцию (доход или расход) и возвращает её локальный ID.
  int addTransaction(Transaction transaction) {
    return _transactionBox.put(transaction);
  }

  /// Сохраняет транзакцию: если `localId` уже существует — обновляет запись,
  /// иначе создаёт новую (поведение ObjectBox `Box.put`).
  void saveTransaction(Transaction transaction) {
    _linkToExistingTransaction(transaction);
    final id = _transactionBox.put(transaction);
    if (kDebugMode) debugPrint('[LocalDbService] Saved transaction localId: $id');
  }

  /// Переносит на приехавшую с сервера транзакцию `localId` уже существующей
  /// локальной строки с тем же `serverId`, чтобы `put` её обновил, а не
  /// создал вторую.
  ///
  /// Без этого шага `put` вставил бы новую строку с тем же `serverId`, а он
  /// помечен `@Unique()` со стратегией по умолчанию `ConflictStrategy.fail` —
  /// то есть вставка не «перезаписала бы тихо», а бросила
  /// `UniqueViolationException` и оборвала синхронизацию.
  /// [claimed] — локальные `localId`, уже занятые другими записями в рамках
  /// одного прохода сверки; нужен, чтобы две серверные записи не «прилипли»
  /// к одной локальной строке.
  void _linkToExistingTransaction(Transaction transaction,
      {Set<int>? claimed}) {
    final serverId = transaction.serverId;
    if (serverId == null) return;

    final query =
        _transactionBox.query(Transaction_.serverId.equals(serverId)).build();
    final existing = query.findFirst();
    query.close();

    if (existing != null) {
      transaction.localId = existing.localId;
      claimed?.add(existing.localId);
      return;
    }

    // Записи с таким serverId локально нет. Прежде чем вставлять новую
    // строку, ищем ещё не выгруженную запись с тем же содержимым: скорее
    // всего это та же самая операция, которой выгрузка не успела проставить
    // serverId (ответ `/sync/` вернулся неполным). Без этой проверки она
    // осталась бы в базе рядом с приехавшей копией — получился бы дубль, и
    // он же уехал бы на сервер при следующей выгрузке.
    final twin = _findUnsyncedTransactionTwin(transaction, claimed);

    if (twin != null) {
      transaction.localId = twin.localId;
      claimed?.add(twin.localId);
    }
  }

  /// Ищет невыгруженную локальную транзакцию, совпадающую с [remote] по
  /// содержимому: дата, категория, тип и сумма.
  ///
  /// Сумму сравниваем в Dart, а не в запросе: ObjectBox не умеет
  /// сопоставлять double на точное равенство.
  Transaction? _findUnsyncedTransactionTwin(
    Transaction remote,
    Set<int>? claimed,
  ) {
    final query = _transactionBox
        .query(Transaction_.serverId
            .isNull()
            .and(Transaction_.dateMilliseconds.equals(remote.dateMilliseconds))
            .and(Transaction_.dbCategory.equals(remote.dbCategory))
            .and(Transaction_.dbType.equals(remote.dbType)))
        .build();
    final candidates = query.find();
    query.close();

    for (final candidate in candidates) {
      final isClaimed = claimed?.contains(candidate.localId) ?? false;

      if (!isClaimed && candidate.amount == remote.amount) return candidate;
    }

    return null;
  }

  /// Удаляет транзакцию по локальному ID. Возвращает `true`, если запись
  /// была найдена и удалена.
  bool deleteTransaction(int id) {
    final removed = _transactionBox.remove(id);
    if (kDebugMode) debugPrint('[LocalDbService] Removed transaction $id: $removed');
    return removed;
  }

  /// Массово сохраняет транзакции, которым только что проставили `serverId`
  /// по ответу `/sync/`.
  ///
  /// Без этого шага записи навсегда остаются «несинхронизированными» и
  /// выгружаются на сервер повторно при каждом входе и при каждом нажатии
  /// «Синхронизировать» — у транзакций нет естественного ключа, поэтому
  /// бэкенд создаёт на каждую отправку новую запись с новым UUID.
  void putTransactions(List<Transaction> transactions) {
    if (transactions.isEmpty) return;
    _transactionBox.putMany(transactions);
  }

  /// Возвращает транзакции, ещё не отправленные на сервер (`serverId == null`).
  /// Используется при синхронизации гостевых данных после входа/регистрации.
  List<Transaction> getUnsyncedTransactions() {
    final query = _transactionBox.query(Transaction_.serverId.isNull()).build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Приводит локальные транзакции в соответствие с состоянием сервера.
  ///
  /// [remote] — ПОЛНЫЙ список транзакций пользователя с сервера (по всем
  /// периодам). Метод делает две вещи в одной транзакции записи:
  ///
  /// 1. upsert присланных записей по `serverId`;
  /// 2. удаление локальных записей, у которых `serverId` есть, но в [remote]
  ///    его нет, — значит запись удалили на сервере.
  ///
  /// Записи с `serverId == null` не удаляются никогда: это данные, созданные
  /// офлайн и ещё не выгруженные (см. [getUnsyncedTransactions]). Стереть их
  /// означало бы потерять ровно то, что синхронизация призвана сохранить.
  ///
  /// Вызывать ТОЛЬКО с полным ответом сервера: для отфильтрованной или
  /// частичной выборки «нет в [remote]» не означает «удалено на сервере»,
  /// и сверка снесёт живые данные.
  ///
  /// Одна транзакция записи вместо `put` на каждую запись нужна и для
  /// скорости (на несколько месяцев гостевых данных это сотни строк), и для
  /// атомарности: оборвавшись на середине, метод не оставит базу в
  /// полуобновлённом состоянии.
  ///
  /// Возвращает число удалённых при сверке записей.
  int reconcileTransactions(List<Transaction> remote) {
    return _store.runInTransaction(TxMode.write, () {
      final claimed = <int>{};

      for (final transaction in remote) {
        _linkToExistingTransaction(transaction, claimed: claimed);
      }
      _transactionBox.putMany(remote);

      final remoteIds =
          remote.map((t) => t.serverId).whereType<String>().toSet();

      final stale = _transactionBox
          .getAll()
          .where((t) => t.serverId != null && !remoteIds.contains(t.serverId))
          .map((t) => t.localId)
          .toList();

      _transactionBox.removeMany(stale);
      return stale.length;
    });
  }

  // --- Бюджеты ---

  /// Возвращает лимиты бюджета за конкретные месяц и год.
  List<Budget> getBudgetsForPeriod(int month, int year) {
    return _budgetBox
        .query(Budget_.month.equals(month).and(Budget_.year.equals(year)))
        .build()
        .find();
  }

  /// Возвращает все сохранённые лимиты бюджета — нужен для полной
  /// синхронизации с бэкендом.
  List<Budget> getAllBudgets() {
    return _budgetBox.getAll();
  }

  /// Сохраняет лимит бюджета. Если лимит на эту категорию за этот месяц/год
  /// уже существует — обновляет его вместо создания дубликата.
  void saveBudget(Budget budget) {
    _linkToExistingBudget(budget);
    final id = _budgetBox.put(budget);
    if (kDebugMode) debugPrint('[LocalDbService] Saved budget localId: $id');
  }

  /// Ищет локальную строку, которую должен обновить этот лимит.
  ///
  /// Порядок проверок важен. Сначала `serverId` — это единственный ключ,
  /// который гарантированно указывает на ту же запись, даже если у неё на
  /// сервере поменяли категорию или период. Только если записи с таким
  /// `serverId` локально нет (или лимит создан офлайн и `serverId` пока
  /// пустой), сопоставляем по натуральному ключу `категория + месяц + год`.
  ///
  /// Раньше проверка по `serverId` отсутствовала, и при полной выгрузке с
  /// сервера строка находилась только по натуральному ключу — из-за чего
  /// `serverId` мог продублироваться между строками и `put` падал с
  /// `UniqueViolationException`.
  void _linkToExistingBudget(Budget budget) {
    final serverId = budget.serverId;

    if (serverId != null) {
      final byServerId =
          _budgetBox.query(Budget_.serverId.equals(serverId)).build();
      final existing = byServerId.findFirst();
      byServerId.close();

      if (existing != null) {
        budget.localId = existing.localId;
        return;
      }
    }

    final byPeriod = _budgetBox
        .query(
          Budget_.dbCategory
              .equals(budget.dbCategory)
              .and(Budget_.month.equals(budget.month))
              .and(Budget_.year.equals(budget.year)),
        )
        .build();
    final existing = byPeriod.findFirst();
    byPeriod.close();

    if (existing != null) {
      budget.localId = existing.localId;
    }
  }

  /// Массово сохраняет бюджеты, которым только что проставили `serverId`
  /// по ответу `/sync/` — см. [putTransactions].
  void putBudgets(List<Budget> budgets) {
    if (budgets.isEmpty) return;
    _budgetBox.putMany(budgets);
  }

  /// Возвращает лимиты бюджета, ещё не отправленные на сервер (`serverId == null`).
  /// Используется при синхронизации гостевых данных после входа/регистрации.
  List<Budget> getUnsyncedBudgets() {
    final query = _budgetBox.query(Budget_.serverId.isNull()).build();
    final results = query.find();
    query.close();
    return results;
  }

  /// Приводит локальные лимиты бюджета в соответствие с состоянием сервера —
  /// см. [reconcileTransactions], правила те же.
  int reconcileBudgets(List<Budget> remote) {
    return _store.runInTransaction(TxMode.write, () {
      for (final budget in remote) {
        _linkToExistingBudget(budget);
      }
      _budgetBox.putMany(remote);

      final remoteIds =
          remote.map((b) => b.serverId).whereType<String>().toSet();

      final stale = _budgetBox
          .getAll()
          .where((b) => b.serverId != null && !remoteIds.contains(b.serverId))
          .map((b) => b.localId)
          .toList();

      _budgetBox.removeMany(stale);
      return stale.length;
    });
  }

  /// Удаляет лимит бюджета по локальному ID. Возвращает `true`, если запись
  /// была найдена и удалена.
  bool deleteBudget(int id) {
    final removed = _budgetBox.remove(id);
    if (kDebugMode) debugPrint('[LocalDbService] Removed budget $id: $removed');
    return removed;
  }

  /// Считает сумму расходов по конкретной категории за месяц и год.
  ///
  /// Примечание: реализовано через полное сканирование всех транзакций —
  /// приемлемо для локальной базы личных финансов, но при росте объёма
  /// данных стоит заменить на запрос ObjectBox с фильтрами по category/type/date.
  double getSpentForCategory(int month, int year, String categoryName) {
    final transactions = getAllTransactions();
    double totalSpent = 0.0;

    for (var t in transactions) {
      if (t.dbCategory == categoryName &&
          t.type == TransactionType.expense &&
          t.date.month == month &&
          t.date.year == year) {
        totalSpent += t.amount;
      }
    }
    return totalSpent;
  }

  Future<void> clearAllData() async {
    _transactionBox.removeAll();
    _budgetBox.removeAll();
  }
}
