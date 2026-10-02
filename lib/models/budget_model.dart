class BudgetModel {
  final String? id;
  final String category;
  final double limitAmount;
  final int month;
  final int year;
  final bool isDeleted;

  BudgetModel({
    this.id,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
    this.isDeleted = false,
  });

  /// Разбирает один элемент бюджета из ответа бэкенда.
  ///
  /// Раньше здесь читалось `json['details']['fields']` — это форма тела
  /// ошибки валидации FastAPI, а не бюджета, поэтому на любом валидном
  /// ответе разбор падал. Элементы `data` приходят плоскими.
  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String?,
      category: json['category'] as String,
      limitAmount: (json['limit_amount'] as num).toDouble(),
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'limit_amount': limitAmount,
      'month': month,
      'year': year,
      if (isDeleted) 'is_deleted': true,
    };
  }
}
