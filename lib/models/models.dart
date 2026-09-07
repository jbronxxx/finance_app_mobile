import 'package:objectbox/objectbox.dart';

enum TransactionType {
  income,
  expense;

  static TransactionType fromString(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => TransactionType.expense,
    );
  }
}

enum Category {
  food, transport, entertainment, health, subscriptions, shopping, salary, other;

  static Category fromString(String type) {
    return Category.values.firstWhere(
      (e) => e.name == type,
      orElse: () => Category.other,
    );
  }
}

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
