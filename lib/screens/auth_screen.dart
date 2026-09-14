import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Экран входа/регистрации.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }
    if (!_isLoginMode && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await ApiService.instance.login(email: email, password: password);
      } else {
        // Отдельный login() здесь не нужен: register() сам логинится после
        // успешной регистрации и сохраняет токен. Раньше вызов дублировался.
        await ApiService.instance.register(
          email: email,
          password: password,
          name: name,
        );
      }

      // Полная двусторонняя синхронизация: сначала выгружаем то, что
      // накопилось в гостевом режиме, затем забираем с сервера актуальное
      // состояние по всем периодам (после переустановки приложения сервер —
      // единственный источник данных). Токен уже сохранён внутри
      // ApiService, поэтому передавать его параметром не нужно.
      try {
        await ApiService.instance.syncAll();
      } catch (e) {
        // Неудачная синхронизация не отменяет вход: локальные данные никуда
        // не делись и уйдут на сервер при следующей попытке.
        debugPrint('Синхронизация после входа не удалась: $e');
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
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
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // <-- 1. Добавили скролл
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                _isLoginMode ? 'С возвращением!' : 'Создать аккаунт',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                _isLoginMode
                    ? 'Войдите, чтобы синхронизировать данные с сервером'
                    : 'Зарегистрируйтесь для доступа к облачному хранилищу',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              if (!_isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Имя',
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
                  labelText: 'Email',
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
                  labelText: 'Пароль',
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
                          _isLoginMode ? 'Войти' : 'Зарегистрироваться',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(
                  height: 24), // <-- 2. Заменили Spacer на фиксированный отступ
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    _isLoginMode
                        ? 'Нет аккаунта? Зарегистрируйтесь'
                        : 'Уже есть аккаунт? Войдите',
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
