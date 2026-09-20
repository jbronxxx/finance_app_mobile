import 'package:family_budget/services/api_service.dart';
import 'package:family_budget/services/preferences_service.dart';
import 'package:family_budget/utils/currency_formatter.dart';
import 'package:family_budget/widgets/swipe_hint_wrapper.dart';
import 'package:flutter/material.dart';
import '../models/local_db_models.dart';
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
  bool _shouldShowSwipeHint = false;

  final List<String> _monthsNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь'
  ];

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _checkSwipeHint();
  }

  void _checkSwipeHint() async {
    final canShow = await PreferencesService.instance.shouldShowSwipeHint('budgets');
    if (canShow) {
      setState(() {
        _shouldShowSwipeHint = true;
      });
    }
  }

  /// Загружает лимиты бюджета за текущие выбранные месяц/год.
  void _loadBudgets() {
    setState(() {
      _budgets = LocalDbService.instance
          .getBudgetsForPeriod(_selectedMonth, _selectedYear);
    });
  }

  /// Удаляет лимит бюджета локально и на сервере.
  void _deleteBudget(Budget budget) {
    ApiService.instance.deleteBudgetEverywhere(budget);
    _loadBudgets();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Лимит удален'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Открывает форму создания или редактирования лимита.
  void _showAddBudgetDialog([Budget? budgetToEdit]) {
    Category selectedCategory = budgetToEdit?.category ?? Category.food;
    final amountController = TextEditingController(
      text: budgetToEdit != null
          ? CurrencyFormatter.format(budgetToEdit.limitAmount,
              showSymbol: false)
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  budgetToEdit != null
                      ? 'Редактировать лимит'
                      : 'Лимит на бюджет',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Category>(
                  value: selectedCategory,
                  borderRadius: BorderRadius.circular(24),
                  alignment: Alignment.centerLeft,
                  decoration: InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  items: Category.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: budgetToEdit != null
                      ? null // Запрещаем менять категорию при редактировании, т.к. это ключ
                      : (val) {
                    if (val != null) {
                      setModalState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: 'Сумма лимита (${CurrencyFormatter.currentCurrency.symbol})',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final amount = CurrencyFormatter.parseInput(amountController.text);
                      if (amount != null && amount > 0) {
                        if (amount > CurrencyFormatter.currentCurrency.maxAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Сумма превышает лимит валюты'),
                            ),
                          );
                          return;
                        }
                        final spent = LocalDbService.instance
                            .getSpentForCategory(_selectedMonth, _selectedYear,
                            selectedCategory.name);
                        final newBudget = Budget(
                          localId: budgetToEdit?.localId ?? 0,
                          serverId: budgetToEdit?.serverId,
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
                    child: Text(
                        budgetToEdit != null
                            ? 'Обновить лимит'
                            : 'Сохранить лимит',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
        title: const Text('Месячные лимиты',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    borderRadius: BorderRadius.circular(24),
                    alignment: Alignment.center,
                    decoration: InputDecoration(
                      labelText: 'Месяц',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: List.generate(12, (index) {
                      final monthValue = index + 1;
                      final isCurrentMonth =
                          monthValue == DateTime.now().month &&
                              _selectedYear == DateTime.now().year;

                      return DropdownMenuItem(
                        value: monthValue,
                        alignment: Alignment.center,
                        child: Text(
                          _monthsNames[index],
                          style: TextStyle(
                            fontWeight: isCurrentMonth
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentMonth
                                ? const Color(0xFF0F766E)
                                : Colors.black87,
                          ),
                        ),
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
                    borderRadius: BorderRadius.circular(24),
                    alignment: Alignment.center,
                    decoration: InputDecoration(
                      labelText: 'Год',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: List.generate(11, (index) {
                      final yearValue = DateTime.now().year + index;
                      final isCurrentYear = yearValue == DateTime.now().year;
                      return DropdownMenuItem(
                        value: yearValue,
                        alignment: Alignment.center,
                        child: Text(
                          '$yearValue',
                          style: TextStyle(
                            fontWeight: isCurrentYear
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentYear
                                ? const Color(0xFF0F766E)
                                : Colors.black87,
                          ),
                        ),
                      );
                    }),
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
                child: Text('Лимиты на этот период не установлены',
                    style: TextStyle(color: Colors.grey)),
              )
                  : ListView.builder(
                itemCount: _budgets.length,
                itemBuilder: (context, index) {
                  final b = _budgets[index];
                  final currentSpent = LocalDbService.instance
                      .getSpentForCategory(
                      _selectedMonth, _selectedYear, b.dbCategory);
                  final progress = b.limitAmount > 0
                      ? (currentSpent / b.limitAmount).clamp(0.0, 1.0)
                      : 0.0;
                  final isExceeded = currentSpent > b.limitAmount;
                  final background = Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Theme.of(context).colorScheme.error,
                    child: const Icon(Icons.delete, color: Colors.white),
                  );

                  Widget item = Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isExceeded
                                ? Colors.orange.shade200
                                : Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: SwipeHintWrapper(
                          showHint: index == 0 && _shouldShowSwipeHint,
                          background: background,
                          onHintShown: () {
                            PreferencesService.instance.recordHintShown('budgets');
                          },
                          child: Dismissible(
                            key: Key('budget_${b.localId}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) => _deleteBudget(b),
                            background: background,
                            child: Material(
                              color: Colors.white,
                              child: InkWell(
                                onTap: () => _showAddBudgetDialog(b),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(b.category.name.toUpperCase(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CurrencyFormatter.formatText(
                                                      currentSpent,
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: isExceeded
                                                              ? Colors.orange.shade800
                                                              : primaryTeal),
                                                    ),
                                                    Text(' / ', style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: isExceeded
                                                            ? Colors.orange.shade800
                                                            : primaryTeal)),
                                                    CurrencyFormatter.formatText(
                                                      b.limitAmount,
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: isExceeded
                                                              ? Colors.orange.shade800
                                                              : primaryTeal),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      LinearProgressIndicator(
                                        value: progress,
                                        color: isExceeded
                                            ? Colors.orange.shade400
                                            : primaryTeal,
                                        backgroundColor: Colors.grey.shade100,
                                        minHeight: 8,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      if (isExceeded) ...[
                                        const SizedBox(height: 8),
                                        Text('Лимит превышен',
                                            style: TextStyle(
                                                color: Colors.orange.shade900,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600))
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );

                  return item;
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