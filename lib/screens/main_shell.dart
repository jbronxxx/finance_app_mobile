import 'dart:async';
import 'package:getbalanceai_mobile/utils/currency_formatter.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';
import 'dashboard_screen.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';

/// Каркас приложения с нижней навигацией.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _userEmail = '';
  String _userName = '';
  late StreamSubscription _authSubscription;

  @override
  void initState() {
    super.initState();
    _userEmail = ApiService.instance.email ?? '';
    _userName = ApiService.instance.userName ?? '';
    _authSubscription =
        ApiService.instance.authStream.listen((isAuthenticated) {
      setState(() {
        _userEmail = ApiService.instance.email ?? '';
        _userName = ApiService.instance.userName ?? '';

        if (!isAuthenticated) {
          _currentIndex = 0;
        }
      });
    });

    // Проверяем первый запуск приложения для выбора языка
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRunLanguageSelection();
    });
  }

  Future<void> _checkFirstRunLanguageSelection() async {
    final savedLang = await PreferencesService.instance.getLanguage();
    if (savedLang == null && mounted) {
      _showWelcomeLanguageSheet();
    }
  }

  void _showWelcomeLanguageSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: PopScope(
          canPop: false, // Запрещаем закрывать по кнопке Назад без выбора
          child: Container(
            padding:
                const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 32),
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
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  LanguageManager.t('welcome_lang_title'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  LanguageManager.t('welcome_lang_subtitle'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      children: [
                        ...AppLanguage.values.map((lang) {
                          final isSelected =
                              LanguageManager.currentLanguage == lang;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F766E)
                                      .withValues(alpha: 0.05)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0F766E)
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                '${lang.flag}   ${lang.displayName}',
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFF0F766E)
                                      : Colors.black87,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF0F766E))
                                  : const Icon(Icons.circle_outlined,
                                      color: Colors.grey),
                              onTap: () {
                                LanguageManager.setLanguage(lang);
                                setModalState(() {});
                                setState(() {}); // Перерисовываем оболочку
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
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
                              Navigator.pop(context);
                            },
                            child: Text(
                              LanguageManager.t('continue_btn'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  /// Переключение на вкладку профиля (индекс 3).
  void _openProfileTab() {
    setState(() {
      _currentIndex = 3;
    });
  }

  void _onAuthenticated(String email, String name) {
    setState(() {
      _userEmail = email;
      _userName = name;
    });
  }

  void _logout() {
    ApiService.instance.performLogout();
  }

  List<Widget> get _screens => [
        DashboardScreen(
          onAuthenticated: _onAuthenticated,
          onOpenProfile: _openProfileTab,
        ),
        const BudgetsScreen(),
        const InsightsScreen(),
        ProfileScreen(
          userEmail: _userEmail,
          userName: _userName,
          onLogout: _logout,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    // Слушаем изменение валюты, чтобы мгновенно обновить всё приложение
    return ValueListenableBuilder<Currency>(
      valueListenable: CurrencyFormatter.currencyNotifier,
      builder: (context, currency, child) {
        return Scaffold(
          body: _screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            indicatorColor: primaryTeal.withValues(alpha: 0.2),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.wallet_outlined),
                selectedIcon: const Icon(Icons.wallet, color: primaryTeal),
                label: LanguageManager.t('balance'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.pie_chart_outline),
                selectedIcon: const Icon(Icons.pie_chart, color: primaryTeal),
                label: LanguageManager.t('limits'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.lightbulb_outline),
                selectedIcon: const Icon(Icons.lightbulb, color: primaryTeal),
                label: LanguageManager.t('insights'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person, color: primaryTeal),
                label: LanguageManager.t('profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
