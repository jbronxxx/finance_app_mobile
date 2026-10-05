import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../widgets/app_alerts.dart';
import '../utils/app_error_handler.dart';
import '../utils/language_manager.dart';

/// Экран входа/регистрации.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  /// Проверяет соответствие пароля правилам безопасности:
  /// длина минимум 6 символов, максимум 72 байта (UTF-8), наличие хотя бы одной буквы и одной цифры.
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return LanguageManager.t('fill_all_fields');
    }

    // Проверяем длину в байтах, так как серверный bcrypt поддерживает максимум 72 байта
    final byteLength = utf8.encode(password).length;
    if (byteLength > 72) {
      return LanguageManager.t('password_too_long_bytes');
    }

    if (password.length < 6) {
      return LanguageManager.t('password_validation_error');
    }
    // Проверка регулярными выражениями наличия буквенных символов и цифр
    final hasLetter =
        RegExp(r'[a-zA-Z\p{L}]', unicode: true).hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    if (!hasLetter || !hasDigit) {
      return LanguageManager.t('password_validation_error');
    }
    return null;
  }

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;
  bool _isLoading = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Обработка входа/регистрации через ApiService.
  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppAlerts.warning(context, LanguageManager.t('fill_all_fields'));
      return;
    }
    if (!_isLoginMode && name.isEmpty) {
      AppAlerts.warning(context, LanguageManager.t('enter_name_alert'));
      return;
    }

    if (!_isLoginMode) {
      final passwordError = AuthScreen.validatePassword(password);
      if (passwordError != null) {
        AppAlerts.warning(context, passwordError);
        return;
      }
    }

    setState(() => _isLoading = true);

    // Проверка интернета перед авторизацией
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppAlerts.noInternet(context);
      }
      return;
    }

    try {
      if (_isLoginMode) {
        await ApiService.instance.login(email: email, password: password);
      } else {
        await ApiService.instance.register(
          email: email,
          password: password,
          name: name,
        );
      }

      try {
        await ApiService.instance.syncAll();
      } catch (e) {
        debugPrint('Синхронизация после входа не удалась: $e');
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorHandler.show(
        context,
        e,
        title: LanguageManager.t(
            _isLoginMode ? 'login_error_title' : 'register_error_title'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                LanguageManager.t(
                    _isLoginMode ? 'welcome_back' : 'create_account'),
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                LanguageManager.t(
                    _isLoginMode ? 'login_subtitle' : 'register_subtitle'),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              if (!_isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: LanguageManager.t('name_label'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: LanguageManager.t('email_label'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: LanguageManager.t('password_label'),
                  helperText: !_isLoginMode
                      ? LanguageManager.t('password_requirements_hint')
                      : null,
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.lock_outline),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          LanguageManager.t(
                              _isLoginMode ? 'login_btn' : 'register_btn'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    LanguageManager.t(_isLoginMode
                        ? 'no_account_prompt'
                        : 'have_account_prompt'),
                    style: const TextStyle(
                        color: primaryTeal, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
