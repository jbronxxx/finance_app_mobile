import 'package:flutter/material.dart';

/// Экран профиля пользователя.
///
/// [userEmail]/[userName] приходят из [MainShell] (пустые строки — гостевой
/// режим, данные ещё не подключены к реальному состоянию аутентификации).
/// [onLogout] сбрасывает это состояние наверху.
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

  /// ВНИМАНИЕ: это имитация — реального запроса к бэкенду тут нет
  /// (просто `Future.delayed`). Реальную синхронизацию должен выполнять
  /// [ApiService.syncLocalDataToBackend] с JWT-токеном текущего пользователя.
  void _startSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatusText = 'Синхронизация с FastAPI...';
      _syncIcon = Icons.sync;
      _syncColor = Colors.orange;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _syncStatusText = 'Синхронизировано успешно (только что)';
      _syncIcon = Icons.cloud_done;
      _syncColor = const Color(0xFF0F766E);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Данные успешно отправлены на сервер')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 48,
                backgroundColor: primaryTeal.withValues(alpha: 0.15),
                child: Text(
                  widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryTeal),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.userName.isNotEmpty ? widget.userName.toUpperCase() : 'ПОЛЬЗОВАТЕЛЬ',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                widget.userEmail,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Статус синхронизации',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primaryTeal),
                              )
                            : Icon(_syncIcon, color: _syncColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _syncStatusText,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal.withValues(alpha: 0.1),
                          foregroundColor: primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSyncing ? null : _startSync,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Синхронизировать сейчас', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    widget.onLogout();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
