import 'package:family_budget/screens/profile_screen.dart';
import 'package:family_budget/services/api_service.dart';
import 'package:family_budget/services/preferences_service.dart';
import 'package:family_budget/widgets/swipe_hint_wrapper.dart';
import 'package:flutter/material.dart';
import '../models/local_db_models.dart';
import '../services/local_db_service.dart';
import 'add_transaction_sheet.dart';
import 'auth_screen.dart';

/// Главный экран: баланс за выбранный период и список операций.
///
/// [onAuthenticated] вызывается после успешного входа/регистрации в
/// [AuthScreen] и поднимает данные пользователя в [MainShell], который
/// передаёт их дальше в экран профиля.
///
/// [onOpenProfile] просит [MainShell] переключиться на вкладку профиля —
/// так залогиненный пользователь попадает в профиль с нижней навигацией,
/// а не в отдельный экран поверх стека.
class DashboardScreen extends StatefulWidget {
  final void Function(String email, String name)? onAuthenticated;
  final VoidCallback? onOpenProfile;

  const DashboardScreen({super.key, this.onAuthenticated, this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Transaction> _transactions = [];
  Map<DateTime, Map<Category, List<Transaction>>> _groupedTransactions = {};
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalBalance = 0;

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

  final List<String> _monthsNamesGenitive = [
    'Января',
    'Февраля',
    'Марта',
    'Апреля',
    'Мая',
    'Июня',
    'Июля',
    'Августа',
    'Сентября',
    'Октября',
    'Ноября',
    'Декабря'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _checkSwipeHint();
  }

  void _checkSwipeHint() async {
    final canShow = await PreferencesService.instance.shouldShowSwipeHint('dashboard');
    if (canShow) {
      setState(() {
        _shouldShowSwipeHint = true;
      });
    }
  }

  /// Перечитывает транзакции из локальной БД и оставляет только те, что
  /// относятся к выбранному месяцу/году (фильтрация — на клиенте, т.к.
  /// ObjectBox хранит дату как unix-миллисекунды, а не отдельные поля).
  void _loadTransactions() {
    final all = LocalDbService.instance.getAllTransactions();
    final filtered = all.where((t) {
      return t.date.month == _selectedMonth && t.date.year == _selectedYear;
    }).toList();

    double income = 0;
    double expense = 0;

    for (var t in filtered) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    final Map<DateTime, Map<Category, List<Transaction>>> grouped = {};
    for (var t in filtered) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(t.category, () => []);
      grouped[date]![t.category]!.add(t);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, Map<Category, List<Transaction>>> sortedGrouped = {};
    for (var date in sortedDates) {
      sortedGrouped[date] = grouped[date]!;
    }

    setState(() {
      _transactions = filtered;
      _totalIncome = income;
      _totalExpense = expense;
      _totalBalance = income - expense;
      _groupedTransactions = sortedGrouped;
    });
  }

  /// Удаляет запись и локально, и на сервере.
  ///
  /// Через ApiService, а не напрямую через LocalDbService: удалённая только
  /// локально запись осталась бы на сервере и вернулась при следующей
  /// синхронизации. Если сети нет, удаление встанет в очередь и повторится
  /// позже — поэтому ответа не ждём и список обновляем сразу.
  void _deleteTransaction(Transaction transaction) {
    ApiService.instance.deleteTransactionEverywhere(transaction);
    _loadTransactions();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запись удалена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Открывает форму добавления новой записи или редактирования существующей.
  void _openTransactionSheet([Transaction? transaction]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(transactionToEdit: transaction),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  /// Открывает экран входа/регистрации; при успешном завершении сообщает
  /// данные пользователя наверх через [DashboardScreen.onAuthenticated]
  /// и перенаправляет пользователя в профиль.
  void _openAuthScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (!mounted) return;

    // Именно _loadTransactions, а не пустой setState: вход запускает полную
    // синхронизацию, и в локальной базе теперь могут быть записи, приехавшие
    // с сервера (после переустановки приложения — вообще все).
    _loadTransactions();

    // AuthScreen просто закрывается после успешного входа, поэтому результат
    // читаем из ApiService — там уже лежат токен и профиль пользователя.
    if (ApiService.instance.isAuthenticated) {
      widget.onAuthenticated?.call(
        ApiService.instance.email ?? '',
        ApiService.instance.userName ?? '',
      );
      _openProfile();
    }
  }

  /// Переход в профиль: по возможности переключаем вкладку в [MainShell],
  /// иначе (экран используется отдельно) открываем профиль поверх стека.
  void _openProfile() async {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userEmail: ApiService.instance.email ?? '',
          userName: ApiService.instance.userName ?? '',
          onLogout: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  /// Подпись кнопки в AppBar: имя пользователя, иначе email, иначе «Профиль».
  String get _userLabel {
    final name = ApiService.instance.userName;
    if (name != null && name.isNotEmpty) return name;

    final email = ApiService.instance.email;
    if (email != null && email.isNotEmpty) return email;

    return 'Профиль';
  }

  void _showPeriodPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Выберите период',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      borderRadius: BorderRadius.circular(24),
                      alignment: Alignment.center,
                      decoration: InputDecoration(
                        labelText: 'Месяц',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      items: List.generate(12, (index) {
                        final monthValue = index + 1;
                        final isCurrentMonth = monthValue == DateTime.now().month &&
                            tempYear == DateTime.now().year;

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
                        if (val != null) setModalState(() => tempMonth = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      borderRadius: BorderRadius.circular(24),
                      alignment: Alignment.center,
                      decoration: InputDecoration(
                        labelText: 'Год',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
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
                        if (val != null) setModalState(() => tempYear = val);
                      },
                    ),
                  ),
                ],
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
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                      _loadTransactions();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Применить',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
    String currentMonthName = _monthsNames[_selectedMonth - 1];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: GestureDetector(
          onTap: _showPeriodPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currentMonthName $_selectedYear',
                style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.black87),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ApiService.instance.isAuthenticated
                ? TextButton.icon(
              onPressed: _openProfile,
              icon: const Icon(Icons.person, size: 18),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  _userLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                backgroundColor:
                const Color(0xFF0F766E).withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
                : TextButton(
              onPressed: _openAuthScreen,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                backgroundColor:
                const Color(0xFF0F766E).withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Вход / Регистрация',
                style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!ApiService.instance.isAuthenticated)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.amber.shade800),
                            const SizedBox(width: 8),
                            Text(
                              'Режим гостя (данные хранятся локально)',
                              style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    _buildBalanceCard(_totalBalance, _totalIncome, _totalExpense),
                    const SizedBox(height: 24),
                    const Text(
                      'История операций',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40.0),
                        child: Center(
                          child: Text(
                            'В этом месяце пока нет записей',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_transactions.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final date = _groupedTransactions.keys.elementAt(index);
                      final categories = _groupedTransactions[date]!;

                      return _buildDayGroup(
                        date,
                        categories,
                        showHintOnFirstCategory: index == 0 && _shouldShowSwipeHint,
                      );
                    },
                    childCount: _groupedTransactions.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionSheet(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double income, double expense) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Общий баланс',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(0)} ₽',
            style: const TextStyle(
                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeExpenseInfo(
                  'Доход', income, Icons.arrow_downward, Colors.white),
              _buildIncomeExpenseInfo(
                  'Расход', expense, Icons.arrow_upward, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseInfo(
      String label, double amount, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              '${amount.toStringAsFixed(0)} ₽',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupedTransactionList() {
    final grouped = _groupTransactions();
    return ListView.builder(
      itemCount: grouped.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final categories = grouped[date]!;
        return _buildDayGroup(date, categories);
      },
    );
  }

  Map<DateTime, Map<Category, List<Transaction>>> _groupTransactions() {
    final Map<DateTime, Map<Category, List<Transaction>>> grouped = {};
    for (var t in _transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(t.category, () => []);
      grouped[date]![t.category]!.add(t);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, Map<Category, List<Transaction>>> sortedGrouped = {};
    for (var date in sortedDates) {
      sortedGrouped[date] = grouped[date]!;
    }
    return sortedGrouped;
  }

  Widget _buildDayGroup(DateTime date, Map<Category, List<Transaction>> categories,
      {bool showHintOnFirstCategory = false}) {
    final dayStr = date.day.toString();
    final monthStr = _monthsNamesGenitive[date.month - 1];
    final isToday = DateTime.now().year == date.year &&
        DateTime.now().month == date.month &&
        DateTime.now().day == date.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            isToday ? 'Сегодня, $dayStr $monthStr' : '$dayStr $monthStr',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ...categories.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final categoryEntry = entry.value;
          return _buildCategoryGroup(
            categoryEntry.key,
            categoryEntry.value,
            showHintOnFirstTransaction: showHintOnFirstCategory && idx == 0,
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCategoryGroup(Category category, List<Transaction> transactions,
      {bool showHintOnFirstTransaction = false}) {
    final total = transactions.fold<double>(0, (sum, t) {
      return t.type == TransactionType.income ? sum + t.amount : sum - t.amount;
    });

    IconData categoryIcon = Icons.category;
    Color categoryColor = Colors.grey.shade400;
    Color bgColor = Colors.grey.shade50;

    if (category == Category.food) {
      categoryIcon = Icons.shopping_cart;
      categoryColor = Colors.orange.shade400;
      bgColor = Colors.orange.shade50;
    } else if (category == Category.transport) {
      categoryIcon = Icons.directions_bus;
      categoryColor = Colors.blue.shade400;
      bgColor = Colors.blue.shade50;
    } else if (category == Category.salary) {
      categoryIcon = Icons.monetization_on;
      categoryColor = Colors.teal.shade400;
      bgColor = Colors.teal.shade50;
    } else if (category == Category.entertainment) {
      categoryIcon = Icons.movie;
      categoryColor = Colors.purple.shade400;
      bgColor = Colors.purple.shade50;
    } else if (category == Category.health) {
      categoryIcon = Icons.medical_services;
      categoryColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else if (category == Category.shopping) {
      categoryIcon = Icons.shopping_bag;
      categoryColor = Colors.pink.shade400;
      bgColor = Colors.pink.shade50;
    } else if (category == Category.subscriptions) {
      categoryIcon = Icons.subscriptions;
      categoryColor = Colors.indigo.shade400;
      bgColor = Colors.indigo.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        key: Key('expansion_${category.name}_$showHintOnFirstTransaction'),
        initiallyExpanded: showHintOnFirstTransaction,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(categoryIcon, color: categoryColor, size: 20),
        ),
        title: Text(
          category.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        trailing: Text(
          '${total >= 0 ? "+" : ""}${total.toStringAsFixed(0)} ₽',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: total >= 0 ? Colors.teal.shade700 : Colors.black87,
          ),
        ),
        children: transactions.asMap().entries.map((entry) {
          return _buildTransactionItem(
            entry.value,
            isFirst: entry.key == 0,
            showHint: showHintOnFirstTransaction && entry.key == 0,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction, {bool isFirst = false, bool showHint = false}) {
    final isExpense = transaction.type == TransactionType.expense;

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).colorScheme.error,
      child: const Icon(Icons.delete, color: Colors.white),
    );

    Widget item = Dismissible(
      key: Key(transaction.localId.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteTransaction(transaction);
      },
      background: background,
      child: Material(
        color: Colors.white,
        child: ListTile(
          onTap: () => _openTransactionSheet(transaction),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          title: Text(
            transaction.description.isEmpty ? 'Без описания' : transaction.description,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: Text(
            '${isExpense ? "-" : "+"}${transaction.amount.toStringAsFixed(0)} ₽',
            style: TextStyle(
              fontSize: 14,
              color: isExpense ? Colors.grey.shade700 : Colors.teal.shade600,
            ),
          ),
        ),
      ),
    );

    if (isFirst) {
      return SwipeHintWrapper(
        showHint: showHint,
        background: background,
        onHintShown: () {
          PreferencesService.instance.recordHintShown('dashboard');
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) setState(() => _shouldShowSwipeHint = false);
          });
        },
        child: item,
      );
    }

    return item;
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isExpense = transaction.type == TransactionType.expense;

    IconData categoryIcon = Icons.category;
    if (transaction.category == Category.food) {
      categoryIcon = Icons.shopping_cart;
    }
    if (transaction.category == Category.transport) {
      categoryIcon = Icons.directions_bus;
    }
    if (transaction.category == Category.salary) {
      categoryIcon = Icons.monetization_on;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Dismissible(
          key: Key(transaction.localId.toString()),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _deleteTransaction(transaction);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                    isExpense ? Colors.orange.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    categoryIcon,
                    color:
                    isExpense ? Colors.orange.shade400 : Colors.teal.shade400,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category.name.toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (transaction.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          transaction.description,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                ),
                Text(
                  '${isExpense ? "-" : "+"}${transaction.amount.toStringAsFixed(0)} ₽',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isExpense ? Colors.black87 : Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}