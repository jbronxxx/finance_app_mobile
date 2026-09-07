import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

/// Каркас приложения с нижней навигацией.
///
/// Здесь же хранится состояние авторизации (`_userEmail`/`_userName`):
/// единого стека аутентификации в приложении нет (см. AuthScreen — это
/// пока форма-заглушка без реального бэкенда), поэтому данные пользователя
/// просто поднимаются на уровень выше экранов, которым они нужны
/// (DashboardScreen передаёт их сюда через [_onAuthenticated] после
/// успешного входа, а ProfileScreen получает их для отображения и выхода).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _userEmail = '';
  String _userName = '';

  void _onAuthenticated(String email, String name) {
    setState(() {
      _userEmail = email;
      _userName = name;
    });
  }

  void _logout() {
    setState(() {
      _userEmail = '';
      _userName = '';
    });
  }

  List<Widget> get _screens => [
        DashboardScreen(onAuthenticated: _onAuthenticated),
        const BudgetsScreen(),
        const InsightsScreen(),
        ProfileScreen(
          userEmail: _userEmail,
          userName: _userName,
          onLogout: _logout,
        ),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wallet_outlined),
            selectedIcon: Icon(Icons.wallet, color: primaryTeal),
            label: 'Баланс',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart, color: primaryTeal),
            label: 'Лимиты',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb, color: primaryTeal),
            label: 'Инсайты',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: primaryTeal),
            label: 'Профиль',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: primaryTeal),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
