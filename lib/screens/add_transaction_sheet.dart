import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/local_db_service.dart';

/// Модальная форма создания/редактирования транзакции.
///
/// Если [transactionToEdit] передан — форма предзаполняется его данными и
/// сохранение обновляет существующую запись (сохраняя `localId`/дату),
/// иначе создаётся новая запись с текущей датой и временем.
class AddTransactionSheet extends StatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionSheet({super.key, this.transactionToEdit});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late TransactionType _type;
  late Category _category;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final t = widget.transactionToEdit;
    _type = t?.type ?? TransactionType.expense;
    _category = t?.category ?? Category.food;
    _amountController = TextEditingController(text: t != null ? t.amount.toString() : '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Валидирует сумму (принимает и запятую, и точку как десятичный
  /// разделитель) и сохраняет транзакцию — новую или обновлённую.
  void _save() {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) return;

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      final updated = Transaction(
        localId: t.localId,
        dbType: _type.name,
        dbCategory: _category.name,
        amount: amount,
        dateMilliseconds: t.date.millisecondsSinceEpoch,
        description: _descriptionController.text.trim(),
      );
      LocalDbService.instance.saveTransaction(updated);
    } else {
      final newTransaction = Transaction(
        dbType: _type.name,
        dbCategory: _category.name,
        amount: amount,
        dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
        description: _descriptionController.text.trim(),
      );
      LocalDbService.instance.saveTransaction(newTransaction);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);
    final isEditing = widget.transactionToEdit != null;

    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Редактировать запись' : 'Новая запись',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = TransactionType.expense),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _type == TransactionType.expense ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _type == TransactionType.expense
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        'Расход',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _type == TransactionType.expense ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = TransactionType.income),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _type == TransactionType.income ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _type == TransactionType.income
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        'Доход',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _type == TransactionType.income ? primaryTeal : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: !isEditing,
            decoration: InputDecoration(
              labelText: 'Сумма (₽)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Category>(
            value: _category,
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
              if (val != null) setState(() => _category = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Описание (необязательно)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _save,
              child: Text(
                isEditing ? 'Сохранить изменения' : 'Добавить запись',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
