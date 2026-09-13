class SyncModel {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;

  SyncModel({required this.transactions, required this.budgets});

  Map<String, dynamic> toJson() => {
        'transactions': transactions,
        'budgets': budgets,
      };
}
