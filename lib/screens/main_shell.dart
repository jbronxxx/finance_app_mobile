import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import '../main.dart';

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
      if (!isAuthenticated) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
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
