import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/local_db_service.dart';

/// Экран лимитов бюджета: показывает установленные лимиты по категориям за
/// выбранный месяц/год и позволяет добавить новый лимит.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Budget> _budgets = [];

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  /// Загружает лимиты бюджета за текущие выбранные месяц/год.
  void _loadBudgets() {
    setState(() {
      _budgets = LocalDbService.instance.getBudgetsForPeriod(_selectedMonth, _selectedYear);
    });
  }

  /// Открывает форму создания лимита: считает уже потраченное по выбранной
  /// категории на момент создания (снимок для полей `spent`/`remaining`)
  /// и сохраняет новый или обновлённый лимит в БД.
  void _showAddBudgetDialog() {
    Category selectedCategory = Category.food;
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Лимит на бюджет',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Category>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: Category.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Сумма лимита (₽)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text.trim());
                    if (amount != null && amount > 0) {
                      final spent = LocalDbService.instance.getSpentForCategory(_selectedMonth, _selectedYear, selectedCategory.name);
                      final newBudget = Budget(
                        dbCategory: selectedCategory.name,
                        limitAmount: amount,
                        month: _selectedMonth,
                        year: _selectedYear,
                        spent: spent,
                        remaining: amount - spent,
                      );
                      LocalDbService.instance.saveBudget(newBudget);
                      Navigator.pop(context);
                      _loadBudgets();
                    }
                  },
                  child: const Text('Сохранить лимит', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Месячные лимиты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: InputDecoration(
                      labelText: 'Месяц',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text('Месяц ${index + 1}'),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMonth = val;
                          _loadBudgets();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Год',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [2025, 2026, 2027].map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedYear = val;
                          _loadBudgets();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _budgets.isEmpty
                  ? const Center(
                      child: Text('Лимиты на этот период не установлены', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: _budgets.length,
                      itemBuilder: (context, index) {
                        final b = _budgets[index];
                        final currentSpent = LocalDbService.instance.getSpentForCategory(_selectedMonth, _selectedYear, b.dbCategory);
                        final progress = b.limitAmount > 0 ? (currentSpent / b.limitAmount).clamp(0.0, 1.0) : 0.0;
                        final isExceeded = currentSpent > b.limitAmount;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isExceeded ? Colors.red.shade300 : Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(b.category.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${currentSpent.toStringAsFixed(0)} / ${b.limitAmount.toStringAsFixed(0)} ₽',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isExceeded ? Colors.red : primaryTeal)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: progress,
                                color: isExceeded ? Colors.red : primaryTeal,
                                backgroundColor: Colors.grey.shade100,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              if (isExceeded) ...[
                                const SizedBox(height: 8),
                                const Text('Лимит превышен!', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                              ]
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
