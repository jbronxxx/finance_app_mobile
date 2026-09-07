import 'package:objectbox/objectbox.dart';

/// Тип операции: доход или расход.
enum TransactionType {
  income,
  expense;

  /// Строковое значение из БД/JSON -> enum. Неизвестное значение трактуется
  /// как расход — самый безопасный дефолт для финансового приложения (лучше
  /// по ошибке показать лишний расход, чем скрыть трату).
  static TransactionType fromString(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Категория транзакции/бюджета.
enum Category {
  food, transport, entertainment, health, subscriptions, shopping, salary, other;

  /// Строковое значение из БД/JSON -> enum. Неизвестная категория
  /// (например, добавленная бэкендом позже, но ещё не поддержанная в
  /// клиенте) сворачивается в [Category.other], а не падает с ошибкой.
  static Category fromString(String type) {
    return Category.values.firstWhere(
      (e) => e.name == type,
      orElse: () => Category.other,
    );
  }
}

/// Запись о доходе или расходе.
///
/// Хранится локально в ObjectBox (`localId` — первичный ключ базы) и
/// синхронизируется с бэкендом (`serverId` — ID записи на сервере, `null`
/// пока запись не отправлена — см. [LocalDbService.getUnsyncedTransactions]).
///
/// `dbCategory`/`dbType`/`dateMilliseconds` — представление, понятное
/// ObjectBox (энумы и DateTime он напрямую не хранит), а типобезопасные
/// [category]/[type]/[date] — то, чем пользуется остальной код.
@Entity()
class Transaction {
  @Id()
  int localId;

  @Unique()
  String? serverId;

  final double amount;
  final String description;
  final String dbCategory;
  final String dbType;
  final int dateMilliseconds;

  Transaction({
    this.localId = 0,
    this.serverId,
    required this.amount,
    required this.description,
    required this.dbCategory,
    required this.dbType,
    required this.dateMilliseconds,
  });

  @Transient()
  Category get category => Category.fromString(dbCategory);

  @Transient()
  TransactionType get type => TransactionType.fromString(dbType);

  @Transient()
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMilliseconds);

  /// Разбирает ответ бэкенда (FastAPI) в локальную модель.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      serverId: json['id'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] ?? '',
      dbCategory: json['category'],
      dbType: json['type'],
      dateMilliseconds: DateTime.parse(json['date']).millisecondsSinceEpoch,
    );
  }

  /// Формирует тело запроса к бэкенду в формате его API.
  Map<String, dynamic> toJson() {
    return {
      if (serverId != null) 'id': serverId,
      'amount': amount,
      'description': description,
      'category': category.name,
      'type': type.name,
      'date': date.toIso8601String(),
    };
  }
}

/// Лимит расходов по категории на конкретный месяц/год.
///
/// `spent`/`remaining` — снимок состояния на момент сохранения лимита;
/// актуальные потраченные суммы для отображения в UI пересчитываются на
/// лету через [LocalDbService.getSpentForCategory], а не берутся из этих
/// полей напрямую.
@Entity()
class Budget {
  @Id()
  int localId;

  @Unique()
  String? serverId;

  final String dbCategory;
  final double limitAmount;
  final int month;
  final int year;
  final double spent;
  final double remaining;

  Budget({
    this.localId = 0,
    this.serverId,
    required this.dbCategory,
    required this.limitAmount,
    required this.month,
    required this.year,
    required this.spent,
    required this.remaining,
  });

  @Transient()
  Category get category => Category.fromString(dbCategory);

  /// Разбирает ответ бэкенда (FastAPI) в локальную модель.
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      serverId: json['id'],
      dbCategory: json['category'],
      limitAmount: (json['limit_amount'] as num).toDouble(),
      month: json['month'],
      year: json['year'],
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
