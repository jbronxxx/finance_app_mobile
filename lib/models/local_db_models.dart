import 'package:objectbox/objectbox.dart';

/// Разбирает дату из ответа бэкенда, возвращая `null` вместо исключения.
///
/// Бэкенд отдаёт ISO-строку, но поле может отсутствовать или прийти не
/// строкой; `DateTime.parse` в этих случаях бросает исключение и роняет
/// разбор всей выгрузки, поэтому используется `tryParse`.
DateTime? parseServerDate(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

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
  food,
  transport,
  entertainment,
  health,
  subscriptions,
  shopping,
  salary,
  other;

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
  final int dateCreatedMilliseconds;

  Transaction({
    this.localId = 0,
    this.serverId,
    required this.amount,
    required this.description,
    required this.dbCategory,
    required this.dbType,
    required this.dateMilliseconds,
    required this.dateCreatedMilliseconds,
  });

  @Transient()
  Category get category => Category.fromString(dbCategory);

  @Transient()
  TransactionType get type => TransactionType.fromString(dbType);

  @Transient()
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMilliseconds);

  /// Разбирает ответ бэкенда (FastAPI) в локальную модель.
  ///
  /// Разбор намеренно устойчив к отсутствующим и неожиданным полям: этот
  /// factory — единственная точка входа для данных, приезжающих с сервера
  /// при полной выгрузке (см. `ApiService.syncBackendDataToLocal`), и падение
  /// на одной битой записи оставило бы локальную базу рассинхронизированной.
  /// В частности, `date_created` бэкенд возвращает не во всех ответах,
  /// поэтому при его отсутствии берём дату самой операции.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final date = parseServerDate(json['date']) ?? DateTime.now();

    return Transaction(
      serverId: json['id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      dbCategory: json['category'] as String? ?? Category.other.name,
      dbType: json['type'] as String? ?? TransactionType.expense.name,
      dateMilliseconds: date.millisecondsSinceEpoch,
      dateCreatedMilliseconds: (parseServerDate(json['date_created']) ?? date)
          .millisecondsSinceEpoch,
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
  /// Устойчив к отсутствующим полям — см. [Transaction.fromJson].
  ///
  /// `month`/`year` при отсутствии остаются нулевыми: такая запись не
  /// относится ни к одному периоду, и вызывающая сторона отбрасывает её
  /// через [isValidPeriod], а не пишет в базу мусор.
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      serverId: json['id'] as String?,
      dbCategory: json['category'] as String? ?? Category.other.name,
      limitAmount: (json['limit_amount'] as num?)?.toDouble() ?? 0.0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Относится ли лимит к осмысленному месяцу/году.
  @Transient()
  bool get isValidPeriod => month >= 1 && month <= 12 && year > 0;

  /// Формирует тело запроса к бэкенду в формате его API.
  Map<String, dynamic> toJson() {
    return {
      if (serverId != null) 'id': serverId,
      'category': category.name,
      'limit_amount': limitAmount,
      'month': month,
      'year': year,
    };
  }
}
