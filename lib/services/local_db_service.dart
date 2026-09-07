import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
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
    final store = await openStore(directory: p.join(docsDir.path, "obx-finance"));
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
    _transactionBox.put(transaction);
  }

  /// Удаляет транзакцию по локальному ID. Возвращает `true`, если запись
  /// была найдена и удалена.
  bool deleteTransaction(int id) {
    return _transactionBox.remove(id);
  }

  /// Возвращает транзакции, ещё не отправленные на сервер (`serverId == null`).
  /// Используется при синхронизации гостевых данных после входа/регистрации.
  List<Transaction> getUnsyncedTransactions() {
    final query = _transactionBox.query(Transaction_.serverId.isNull()).build();
    final results = query.find();
    query.close();
    return results;
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
    final existing = _budgetBox
        .query(
          Budget_.dbCategory.equals(budget.dbCategory)
              .and(Budget_.month.equals(budget.month))
              .and(Budget_.year.equals(budget.year)),
        )
        .build()
        .findFirst();

    if (existing != null) {
      budget.localId = existing.localId;
    }
    _budgetBox.put(budget);
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
}
