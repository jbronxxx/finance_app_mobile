import 'local_db_models.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String description;
  final String category;
  final String type;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.type,
    required this.date,
  });

  /// Разбирает транзакцию из ответа бэкенда REST API.
  ///
  /// Поддерживает безопасный парсинг `amount` как из числа (num), так и из
  /// строкового представления `Decimal(12, 2)` / `Numeric(12, 2)`.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      amount: parseAmount(json['amount']),
      description: json['description'] as String,
      category: json['category'] as String,
      type: json['type'] as String,
      date: DateTime.parse(json['date'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category': category,
      'type': type,
      'date': date.toUtc().toIso8601String(),
    };
  }
}
