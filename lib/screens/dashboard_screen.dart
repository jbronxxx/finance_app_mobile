import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/local_db_service.dart';
import 'add_transaction_sheet.dart';
import 'auth_screen.dart';

/// Главный экран: баланс за выбранный период и список операций.
///
/// [onAuthenticated] вызывается после успешного входа/регистрации в
/// [AuthScreen] и поднимает данные пользователя в [MainShell], который
/// передаёт их дальше в экран профиля.
class DashboardScreen extends StatefulWidget {
  final void Function(String email, String name)? onAuthenticated;

  const DashboardScreen({super.key, this.onAuthenticated});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Transaction> _transactions = [];

  final List<String> _monthsNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  /// Перечитывает транзакции из локальной БД и оставляет только те, что
  /// относятся к выбранному месяцу/году (фильтрация — на клиенте, т.к.
  /// ObjectBox хранит дату как unix-миллисекунды, а не отдельные поля).
  void _loadTransactions() {
    final all = LocalDbService.instance.getAllTransactions();
    setState(() {
      _transactions = all.where((t) {
        return t.date.month == _selectedMonth && t.date.year == _selectedYear;
      }).toList();
    });
  }

  void _deleteTransaction(Transaction transaction) {
    LocalDbService.instance.deleteTransaction(transaction.localId);
    _loadTransactions();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запись удалена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Открывает форму добавления новой записи и обновляет список после
  /// успешного сохранения (форма сама пишет в БД и возвращает `true`).
  void _openAddTransactionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  /// Открывает экран входа/регистрации; при успешном завершении сообщает
  /// данные пользователя наверх через [DashboardScreen.onAuthenticated].
  void _openAuthScreen() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (result != null) {
      widget.onAuthenticated?.call(result['email'] ?? '', result['name'] ?? '');
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите период',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: tempMonth,
                decoration: InputDecoration(
                  labelText: 'Месяц',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: List.generate(12, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text(_monthsNames[index]),
                  );
                }),
                onChanged: (val) {
                  if (val != null) setModalState(() => tempMonth = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: tempYear,
                decoration: InputDecoration(
                  labelText: 'Год',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: [2024, 2025, 2026, 2027].map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => tempYear = val);
                },
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
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                      _loadTransactions();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Применить', style: TextStyle(fontWeight: FontWeight.bold)),
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
    double income = 0;
    double expense = 0;

    for (var t in _transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    double balance = income - expense;

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
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
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
            child: TextButton(
              onPressed: _openAuthScreen,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Вход / Регистрация',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Режим гостя (данные хранятся локально)',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            _buildBalanceCard(balance, income, expense),
            const SizedBox(height: 24),
            const Text(
              'История операций',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            _transactions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: Text(
                        'В этом месяце пока нет записей',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _transactions.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      return _buildTransactionCard(transaction);
                    },
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionSheet,
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
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(0)} ₽',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeExpenseInfo('Доход', income, Icons.arrow_downward, Colors.white),
              _buildIncomeExpenseInfo('Расход', expense, Icons.arrow_upward, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseInfo(String label, double amount, IconData icon, Color color) {
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
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              '${amount.toStringAsFixed(0)} ₽',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isExpense = transaction.type == TransactionType.expense;
    
    IconData categoryIcon = Icons.category;
    if (transaction.category == Category.food) categoryIcon = Icons.shopping_cart;
    if (transaction.category == Category.transport) categoryIcon = Icons.directions_bus;
    if (transaction.category == Category.salary) categoryIcon = Icons.monetization_on;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(transaction.localId.toString()),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) {
          _deleteTransaction(transaction);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(24),
          ),
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
                  color: isExpense ? Colors.orange.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  categoryIcon,
                  color: isExpense ? Colors.orange.shade400 : Colors.teal.shade400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (transaction.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        transaction.description,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
    );
  }
}
