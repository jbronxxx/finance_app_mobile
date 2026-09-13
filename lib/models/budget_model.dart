class BudgetModel {
  final String category;
  final double limitAmount;
  final int month;
  final int year;

  BudgetModel({
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    final data = json['details']['fields'];

    return BudgetModel(
      category: data['category'] as String,
      limitAmount: (data['limit_amount'] as num).toDouble(),
      month: data['month'] as int,
      year: data['year'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'limit_amount': limitAmount,
      'month': month,
      'year': year,
    };
  }
}
