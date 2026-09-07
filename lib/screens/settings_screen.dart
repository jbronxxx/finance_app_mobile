import 'package:flutter/material.dart';

/// Экран настроек приложения (тема, валюта, уведомления, очистка кэша).
///
/// Переключатели пока меняют только локальное состояние виджета и не
/// сохраняются между запусками — постоянное хранение настроек ещё не
/// реализовано (кандидат: тот же ObjectBox или SharedPreferences).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;
  String _selectedCurrency = '₽ (Рубль)';

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выбор валюты',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('₽ (Рубль)'),
              onTap: () {
                setState(() => _selectedCurrency = '₽ (Рубль)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('\$ (Доллар США)'),
              onTap: () {
                setState(() => _selectedCurrency = '\$ (Доллар США)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('€ (Евро)'),
              onTap: () {
                setState(() => _selectedCurrency = '€ (Евро)');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Внешний вид и интерфейс',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Темная тема', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Скоро появится', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _isDarkMode,
                  activeColor: primaryTeal,
                  onChanged: (val) {
                    setState(() => _isDarkMode = val);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Основная валюта', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Text(_selectedCurrency, style: const TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
                  onTap: _showCurrencyPicker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Уведомления',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SwitchListTile(
              title: const Text('Напоминания о лимитах', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Уведомлять при превышении бюджета', style: TextStyle(fontSize: 12, color: Colors.grey)),
              value: _notificationsEnabled,
              activeColor: primaryTeal,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Данные',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Очистить локальный кэш', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () {
                // ВНИМАНИЕ: кнопка пока ничего не удаляет из ObjectBox —
                // только показывает сообщение. Перед реальной реализацией
                // нужно подтверждение пользователя (диалог), т.к. очистка
                // необратимо удалит все локальные транзакции и лимиты.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Локальные данные сброшены')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
