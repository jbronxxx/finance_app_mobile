import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'budgets_screen.dart';
import 'insights_screen.dart';
import 'profile_screen.dart';
import '../cubits/auth/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Каркас приложения с нижней навигацией.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: PopScope(
          canPop: false, // Запрещаем закрывать по кнопке Назад без выбора
          child: Container(
            padding: EdgeInsets.only(
                top: 10,
                left: 24,
                right: 24,
                bottom: 32 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
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
                    context.l10n.welcome_lang_title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.welcome_lang_subtitle,
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
                                      : Theme.of(context)
                                          .dividerColor
                                          .withValues(alpha: 0.1),
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
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
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
                                PreferencesService.instance.saveLanguage(
                                    LanguageManager.currentLanguage.code);
                                Navigator.pop(context);
                              },
                              child: Text(
                                context.l10n.continue_btn,
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
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Переключение на вкладку профиля (индекс 3).
  void _openProfileTab() {
    setState(() {
      _currentIndex = 3;
    });
  }

  void _onAuthenticated(String email, String name) {
    // AuthCubit автоматически обновит состояние
  }

  void _logout() {
    context.read<AuthCubit>().logout();
  }

  List<Widget> _getScreens(String email, String name) => [
        DashboardScreen(
          onAuthenticated: _onAuthenticated,
          onOpenProfile: _openProfileTab,
        ),
        const BudgetsScreen(),
        const InsightsScreen(),
        ProfileScreen(
          userEmail: email,
          userName: name,
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
        return BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is Unauthenticated) {
              setState(() {
                _currentIndex = 0;
              });
            }
          },
          builder: (context, authState) {
            String email = '';
            String name = '';
            if (authState is Authenticated) {
              email = authState.email;
              name = authState.name;
            }

            return Scaffold(
              body: _getScreens(email, name)[_currentIndex],
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
                    label: context.l10n.balance,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.pie_chart_outline),
                    selectedIcon:
                        const Icon(Icons.pie_chart, color: primaryTeal),
                    label: context.l10n.limits,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.lightbulb_outline),
                    selectedIcon:
                        const Icon(Icons.lightbulb, color: primaryTeal),
                    label: context.l10n.insights,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person, color: primaryTeal),
                    label: context.l10n.profile,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
