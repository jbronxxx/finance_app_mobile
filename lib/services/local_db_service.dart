import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../objectbox.g.dart'; // Этот файл будет сгенерирован автоматически

class LocalDbService {
  late final Store _store;
  late final Box<Transaction> _transactionBox;
  late final Box<Budget> _budgetBox;

  // Приватный конструктор для Singleton
  LocalDbService._create(this._store) {
    _transactionBox = Box<Transaction>(_store);
    _budgetBox = Box<Budget>(_store);
  }

  // Метод инициализации базы данных. Вызывается один раз при старте приложения.
  static Future<LocalDbService> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: p.join(docsDir.path, "obx-finance"));
    return LocalDbService._create(store);
  }

  // --- МЕТОДЫ ДЛЯ ТРАНЗАКЦИЙ ---

  // Получить все транзакции, отсортированные по дате (от новых к старым)
  List<Transaction> getAllTransactions() {
    final query = _transactionBox.query()
      ..order(Transaction_.dateMilliseconds, flags: Order.descending);
    final q = query.build();
    final results = q.find();
    q.close();
    return results;
  }

  // Добавить новую транзакцию (Доход или Расход)
  int addTransaction(Transaction transaction) {
    return _transactionBox.put(transaction);
  }

  // Обновить существующую транзакцию
  void saveTransaction(Transaction transaction) {
    _transactionBox.put(transaction);
  }

  // Удалить транзакцию по локальному ID
  bool deleteTransaction(int id) {
    return _transactionBox.remove(id);
  }

  // Получить транзакции, которые еще не синхронизированы с сервером (serverId == null)
  List<Transaction> getUnsyncedTransactions() {
    final query = _transactionBox.query(Transaction_.serverId.isNull()).build();
    final results = query.find();
    query.close();
    return results;
  }

  // --- МЕТОДЫ ДЛЯ БЮДЖЕТОВ ---

  /// Получить список бюджетов за конкретный месяц и год
  List<Budget> getBudgetsForPeriod(int month, int year) {
    return _budgetBox
        .query(Budget_.month.equals(month).and(Budget_.year.equals(year)))
        .build()
        .find();
  }

  // Получить вообще все сохраненные бюджеты для синхронизации
  List<Budget> getAllBudgets() {
    return _budgetBox.getAll();
  }

  // Сохранить или обновить лимит бюджета
  void saveBudget(Budget budget) {
    // Проверяем, есть ли уже лимит на эту категорию в этот месяц/год
    final existing = _budgetBox
        .query(
          Budget_.dbCategory.equals(budget.dbCategory)
              .and(Budget_.month.equals(budget.month))
              .and(Budget_.year.equals(budget.year)),
        )
        .build()
        .findFirst();

    if (existing != null) {
      budget.localId = existing.localId; // Обновляем существующий
    }
    _budgetBox.put(budget);
  }

  // Посчитать сумму расходов по конкретной категории за месяц и год
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