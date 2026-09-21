import 'dart:async';

import 'package:family_budget/utils/currency_formatter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Экран профиля пользователя, совмещенный с настройками приложения.
class ProfileScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSyncing = false;
  String _syncStatusText = 'Данные синхронизированы';
  IconData _syncIcon = Icons.cloud_done;
  Color _syncColor = const Color(0xFF0F766E);
  late StreamSubscription<bool> _authSubscription;

  // Состояние настроек (пока локальное)
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = ApiService.instance.authStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  /// Синхронизация данных через ApiService.
  void _startSync() async {
    // Проверка интернета перед синхронизацией
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() {
          _syncStatusText = 'Нет сети';
          _syncIcon = Icons.cloud_off;
          _syncColor = Colors.grey;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Для синхронизации нужно подключение к сети')),
        );
      }
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncStatusText = 'Синхронизация...';
      _syncIcon = Icons.sync;
      _syncColor = Colors.orange;
    });

    try {
      await ApiService.instance.syncAll();
      if (!mounted) return;

      setState(() {
        _isSyncing = false;
        _syncStatusText = 'Обновлено только что';
        _syncIcon = Icons.cloud_done;
        _syncColor = const Color(0xFF0F766E);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные успешно синхронизированы')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncStatusText = 'Ошибка синхронизации';
        _syncIcon = Icons.error_outline;
        _syncColor = Colors.red;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при синхронизации: $e')),
      );
    }
  }

  /// Выбор валюты в модальном окне.
  /// Выбор валюты в модальном окне.
  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
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
            const Text(
              'Выбор валюты',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...Currency.values.map((c) => _buildCurrencyOption(c)),
          ],
        ),
      ),
    );
  }

  /// Опция выбора конкретной валюты.
  Widget _buildCurrencyOption(Currency currency) {
    return ValueListenableBuilder<Currency>(
      valueListenable: CurrencyFormatter.currencyNotifier,
      builder: (context, currentCurrency, child) {
        final isSelected = currentCurrency == currency;
        // Отображаем знак и полное читаемое название
        final label = '${currency.symbol} — ${currency.readableName}';
        return ListTile(
          title: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check, color: Color(0xFF0F766E))
              : null,
          onTap: () {
            // Глобально меняем валюту через форматировщик
            CurrencyFormatter.setCurrency(currency);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _handleLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.instance.logout();
      if (!mounted) return;
      widget.onLogout();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы вышли из системы')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выходе: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);
    final isAuthenticated = ApiService.instance.isAuthenticated;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Профиль',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              // User Info Header
              _buildProfileHeader(primaryTeal, isAuthenticated),
              const SizedBox(height: 32),

              // Sync Status Section
              _buildSectionTitle('Облако'),
              _buildSyncCard(primaryTeal, isAuthenticated),
              const SizedBox(height: 24),

              // Settings Section
              _buildSectionTitle('Интерфейс'),
              _buildSettingsCard(primaryTeal),
              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: isAuthenticated 
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Выйти из аккаунта',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryTeal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _handleLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Войти или создать аккаунт',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color primaryColor, bool isAuthenticated) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          child: Text(
            isAuthenticated && widget.userName.isNotEmpty 
                ? widget.userName[0].toUpperCase() 
                : (isAuthenticated ? 'U' : '?'),
            style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isAuthenticated && widget.userName.isNotEmpty 
              ? widget.userName 
              : (isAuthenticated ? 'Пользователь' : 'Гостевой режим'),
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          isAuthenticated ? widget.userEmail : 'Войдите, чтобы сохранять данные в облаке',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(Color primaryColor, bool isAuthenticated) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAuthenticated && !_isSyncing ? _startSync : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isAuthenticated ? _syncColor : Colors.grey)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: isAuthenticated && _isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _syncColor),
                      )
                    : Icon(isAuthenticated ? _syncIcon : Icons.cloud_off,
                        color: isAuthenticated ? _syncColor : Colors.grey,
                        size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Статус синхронизации',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      isAuthenticated ? _syncStatusText : 'Облако не подключено',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (isAuthenticated)
                Icon(Icons.sync, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(Color primaryColor) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Темная тема',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: const Text('Скоро появится', style: TextStyle(fontSize: 12)),
            value: _isDarkMode,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _isDarkMode = val),
          ),
          ListTile(
            title: const Text('Валюта',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            trailing: ValueListenableBuilder<Currency>(
              valueListenable: CurrencyFormatter.currencyNotifier,
              builder: (context, currency, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currency.readableName,
                        style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                );
              },
            ),
            onTap: _showCurrencyPicker,
          ),
          SwitchListTile(
            title: const Text('Уведомления',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: const Text('Лимиты и бюджеты', style: TextStyle(fontSize: 12)),
            value: _notificationsEnabled,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
        ],
      ),
    );
  }
}
