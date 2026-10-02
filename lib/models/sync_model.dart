class SyncModel {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;
  final List<String>? deletedBudgetIds;
  final List<String>? deletedTransactionIds;

  SyncModel({
    required this.transactions,
    required this.budgets,
    this.deletedBudgetIds,
    this.deletedTransactionIds,
  });

  Map<String, dynamic> toJson() => {
        'transactions': transactions,
        'budgets': budgets,
        if (deletedBudgetIds != null && deletedBudgetIds!.isNotEmpty)
          'deleted_budget_ids': deletedBudgetIds,
        if (deletedTransactionIds != null && deletedTransactionIds!.isNotEmpty)
          'deleted_transaction_ids': deletedTransactionIds,
      };
}
