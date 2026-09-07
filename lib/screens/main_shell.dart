import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'budgets_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const BudgetsScreen(),
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
        ],
      ),
    );
  }
}
