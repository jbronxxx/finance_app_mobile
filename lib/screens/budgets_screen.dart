import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/preferences_service.dart';
import 'package:getbalanceai_mobile/utils/currency_formatter.dart';
import 'package:getbalanceai_mobile/widgets/swipe_hint_wrapper.dart';
import 'package:getbalanceai_mobile/widgets/custom_pull_to_refresh.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../models/local_db_models.dart';
import '../services/local_db_service.dart';
import '../widgets/app_alerts.dart';
import '../utils/app_error_handler.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _checkSwipeHint();
  }

  void _checkSwipeHint() async {
    final canShow =
        await PreferencesService.instance.shouldShowSwipeHint('budgets');
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

  Future<void> _handleRefresh() async {
    if (!ApiService.instance.isAuthenticated) {
      _loadBudgets();
      AppAlerts.warning(context, LanguageManager.t('sync_login_required'));
      return;
    }

    // Проверка интернета перед синхронизацией
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        _loadBudgets();
        AppAlerts.noInternet(
            context, LanguageManager.t('sync_network_required'));
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[Budgets] Starting syncAll via pull-to-refresh');
      }
      await ApiService.instance.syncAll();
      _loadBudgets();
      if (mounted) {
        AppAlerts.success(context, LanguageManager.t('sync_success'));
      }
    } catch (e) {
      if (mounted) {
        _loadBudgets();
        AppErrorHandler.show(context, e,
            title: LanguageManager.t('sync_error'));
      }
    }
  }

  /// Удаляет лимит бюджета локально и на сервере.
  void _deleteBudget(Budget budget) {
    ApiService.instance.deleteBudgetEverywhere(budget);
    _loadBudgets();

    AppAlerts.info(context, LanguageManager.t('budget_deleted'));
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
          padding:
              const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
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
                      ? LanguageManager.t('edit_budget_title')
                      : LanguageManager.t('add_budget_title'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<Category>(
                  value: selectedCategory,
                  borderRadius: BorderRadius.circular(24),
                  alignment: Alignment.centerLeft,
                  decoration: InputDecoration(
                    labelText: LanguageManager.t('category_label'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  items: Category.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.getLocalizedName(context)),
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
                    labelText:
                        '${LanguageManager.t('budget_amount_hint')} (${CurrencyFormatter.currentCurrency.localizedSymbol})',
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
                      final amount =
                          CurrencyFormatter.parseInput(amountController.text);
                      if (amount != null && amount > 0) {
                        if (amount >
                            CurrencyFormatter.currentCurrency.maxAmount) {
                          AppAlerts.warning(context,
                              '${LanguageManager.t('alert_amount_too_large')} ${CurrencyFormatter.currentCurrency.code}');
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
                          isModified: budgetToEdit?.serverId != null,
                        );
                        LocalDbService.instance.saveBudget(newBudget);
                        Navigator.pop(context);
                        _loadBudgets();
                      }
                    },
                    child: Text(
                        budgetToEdit != null
                            ? LanguageManager.t('save_btn')
                            : LanguageManager.t('save_btn'),
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
        title: Text(LanguageManager.t('budgets_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomPullToRefresh(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, top: 16.0, bottom: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedMonth,
                        borderRadius: BorderRadius.circular(24),
                        alignment: Alignment.center,
                        decoration: InputDecoration(
                          labelText: LanguageManager.t('month_label'),
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
                              LanguageManager.monthsNames[index],
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
                          labelText: LanguageManager.t('year_label'),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: List.generate(11, (index) {
                          final yearValue = DateTime.now().year + index;
                          final isCurrentYear =
                              yearValue == DateTime.now().year;
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
              ),
            ),
            if (_budgets.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      LanguageManager.t('no_budgets_subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, bottom: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
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
                                PreferencesService.instance
                                    .recordHintShown('budgets');
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                  b.category.getLocalizedName(
                                                      context),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        CurrencyFormatter
                                                            .formatText(
                                                          currentSpent,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isExceeded
                                                                  ? Colors
                                                                      .orange
                                                                      .shade800
                                                                  : primaryTeal),
                                                        ),
                                                        Text(' / ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: isExceeded
                                                                    ? Colors
                                                                        .orange
                                                                        .shade800
                                                                    : primaryTeal)),
                                                        CurrencyFormatter
                                                            .formatText(
                                                          b.limitAmount,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isExceeded
                                                                  ? Colors
                                                                      .orange
                                                                      .shade800
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
                                            backgroundColor:
                                                Colors.grey.shade100,
                                            minHeight: 8,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          if (isExceeded) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                                '${LanguageManager.t('budget_exceeded')}!',
                                                style: TextStyle(
                                                    color:
                                                        Colors.orange.shade900,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600))
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
                    childCount: _budgets.length,
                  ),
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
