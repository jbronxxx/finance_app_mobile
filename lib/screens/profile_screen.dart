import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:getbalanceai_mobile/utils/currency_formatter.dart';
import '../widgets/app_alerts.dart';
import '../utils/language_manager.dart';
import '../services/preferences_service.dart';
import '../utils/app_error_handler.dart';
import '../cubits/profile/profile_cubit.dart';
import '../cubits/auth/auth_cubit.dart';

/// Экран профиля пользователя, совмещенный с настройками приложения.
class ProfileScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(),
      child: _ProfileScreenView(
        userEmail: userEmail,
        userName: userName,
        onLogout: onLogout,
      ),
    );
  }
}

class _ProfileScreenView extends StatefulWidget {
  final String userEmail;
  final String userName;
  final VoidCallback onLogout;

  const _ProfileScreenView({
    required this.userEmail,
    required this.userName,
    required this.onLogout,
  });

  @override
  State<_ProfileScreenView> createState() => _ProfileScreenViewState();
}

class _ProfileScreenViewState extends State<_ProfileScreenView> {
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications =
        await PreferencesService.instance.getNotificationsEnabled();
    final darkMode = await PreferencesService.instance.getDarkMode();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _isDarkMode = darkMode;
      });
    }
  }

  void _handleSyncState(BuildContext context, ProfileState state) {
    if (state.syncStatus == SyncStatus.noInternet) {
      AppAlerts.noInternet(
          context, LanguageManager.t('sync_no_internet_alert'));
    } else if (state.syncStatus == SyncStatus.success) {
      AppAlerts.success(context, LanguageManager.t('sync_success'));
    } else if (state.syncStatus == SyncStatus.error) {
      AppErrorHandler.show(context, state.syncError,
          title: LanguageManager.t('cloud'));
    }
  }

  /// Выбор валюты в модальном окне.
  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding:
            const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
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
            Text(
              LanguageManager.t('select_currency'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...Currency.values.map((c) => _buildCurrencyOption(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(Currency currency) {
    return ValueListenableBuilder<Currency>(
      valueListenable: CurrencyFormatter.currencyNotifier,
      builder: (context, currentCurrency, child) {
        final isSelected = currentCurrency == currency;
        final currencyNameKey = '${currency.code.toLowerCase()}_name';
        final label =
            '${currency.localizedSymbol} — ${LanguageManager.t(currencyNameKey)}';
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
            CurrencyFormatter.setCurrency(currency);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  /// Выбор языка в модальном окне.
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding:
            const EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 24),
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
            Text(
              LanguageManager.t('select_language'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...AppLanguage.values.map((l) => _buildLanguageOption(l)),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(AppLanguage lang) {
    final isSelected = LanguageManager.currentLanguage == lang;
    final label = '${lang.flag}   ${lang.displayName}';
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: Color(0xFF0F766E)) : null,
      onTap: () {
        LanguageManager.setLanguage(lang);
        Navigator.pop(context);
        setState(() {}); // Обновляем локальное состояние
      },
    );
  }

  void _handleLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  Future<void> _handleLogout() async {
    final cubit = context.read<ProfileCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LanguageManager.t('logout_confirm_title')),
        content: Text(LanguageManager.t('logout_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LanguageManager.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(LanguageManager.t('logout')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await cubit.logout();
    if (!mounted) return;
    widget.onLogout();
    AppAlerts.info(context, LanguageManager.t('logout_info'));
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (previous, current) =>
          previous.syncStatus != current.syncStatus,
      listener: (context, state) {
        _handleSyncState(context, state);
      },
      builder: (context, state) {
        final isAuthenticated =
            context.watch<AuthCubit>().state is Authenticated;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text(LanguageManager.t('profile'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                children: [
                  _buildProfileHeader(primaryTeal, isAuthenticated),
                  const SizedBox(height: 32),
                  _buildSectionTitle(LanguageManager.t('cloud')),
                  _buildSyncCard(
                      primaryTeal, isAuthenticated, state.syncStatus),
                  const SizedBox(height: 24),
                  _buildSectionTitle(LanguageManager.t('interface')),
                  _buildSettingsCard(primaryTeal),
                  const SizedBox(height: 32),
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
                            label: Text(LanguageManager.t('logout'),
                                style: const TextStyle(
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
                            label: Text(LanguageManager.t('login_or_register'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
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
              : (isAuthenticated
                  ? LanguageManager.t('user')
                  : LanguageManager.t('guest_mode')),
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          isAuthenticated
              ? widget.userEmail
              : LanguageManager.t('login_cloud_hint'),
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

  Widget _buildSyncCard(
      Color primaryColor, bool isAuthenticated, SyncStatus status) {
    String syncStatusKey = 'sync_synced';
    IconData syncIcon = Icons.cloud_done;
    Color syncColor = const Color(0xFF0F766E);
    bool isSyncing = status == SyncStatus.syncing;

    if (status == SyncStatus.noInternet) {
      syncStatusKey = 'sync_no_internet';
      syncIcon = Icons.cloud_off;
      syncColor = Colors.grey;
    } else if (status == SyncStatus.syncing) {
      syncStatusKey = 'syncing';
      syncIcon = Icons.sync;
      syncColor = Colors.orange;
    } else if (status == SyncStatus.error) {
      syncStatusKey = 'sync_error';
      syncIcon = Icons.error_outline;
      syncColor = Colors.red;
    } else if (status == SyncStatus.success) {
      syncStatusKey = 'sync_updated_just_now';
      syncIcon = Icons.cloud_done;
      syncColor = const Color(0xFF0F766E);
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAuthenticated && !isSyncing
            ? context.read<ProfileCubit>().startSync
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isAuthenticated ? syncColor : Colors.grey)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: isAuthenticated && isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: syncColor),
                      )
                    : Icon(isAuthenticated ? syncIcon : Icons.cloud_off,
                        color: isAuthenticated ? syncColor : Colors.grey,
                        size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(LanguageManager.t('sync_status'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      isAuthenticated
                          ? LanguageManager.t(syncStatusKey)
                          : LanguageManager.t('cloud_not_connected'),
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
            title: Text(LanguageManager.t('dark_mode'),
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            value: _isDarkMode,
            activeColor: primaryColor,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              PreferencesService.instance.saveDarkMode(val);
            },
          ),
          ListTile(
            title: Text(LanguageManager.t('language'),
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${LanguageManager.currentLanguage.flag} ${LanguageManager.currentLanguage.displayName}',
                  style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: _showLanguagePicker,
          ),
          ListTile(
            title: Text(LanguageManager.t('currency'),
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            trailing: ValueListenableBuilder<Currency>(
              valueListenable: CurrencyFormatter.currencyNotifier,
              builder: (context, currency, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        LanguageManager.t(
                            '${currency.code.toLowerCase()}_name'),
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
            title: Text(LanguageManager.t('notifications'),
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            subtitle: Text(LanguageManager.t('limits_and_budgets'),
                style: const TextStyle(fontSize: 12)),
            value: _notificationsEnabled,
            activeColor: primaryColor,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              PreferencesService.instance.saveNotificationsEnabled(val);
            },
          ),
        ],
      ),
    );
  }
}
