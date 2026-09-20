import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Сервис для управления UX-подсказками.
///
/// Логика:
/// 1. Обучение длится 3 «сессии» (перезапуска приложения).
/// 2. В каждой сессии мы показываем подсказку на каждом экране по 1 разу.
class PreferencesService {
  PreferencesService._internal();
  static final PreferencesService instance = PreferencesService._internal();

  final _storage = const FlutterSecureStorage();
  
  static const _keyTotalSessions = 'ux_hint_sessions_completed';

  // Храним идентификаторы экранов, где хинт уже был показан в этой сессии
  final Set<String> _shownScreensInSession = {};
  bool _sessionAlreadyCounted = false;

  /// Можно ли показать хинт для конкретного экрана?
  Future<bool> shouldShowSwipeHint(String screenId) async {
    final totalSessions = await _getTotalSessions();
    
    // Если пользователь уже прошел 3 сессии обучения — больше не показываем нигде
    if (totalSessions >= 3) return false;
    
    // В рамках одной сессии показываем только если на этом экране еще не видели
    return !_shownScreensInSession.contains(screenId);
  }

  /// Фиксирует факт показа хинта на конкретном экране.
  Future<void> recordHintShown(String screenId) async {
    _shownScreensInSession.add(screenId);

    // Если это вообще первый показ в этой сессии (на любом экране), 
    // увеличиваем счетчик глобальных сессий обучения.
    if (!_sessionAlreadyCounted) {
      _sessionAlreadyCounted = true;
      final total = await _getTotalSessions();
      await _storage.write(key: _keyTotalSessions, value: (total + 1).toString());
    }
  }

  Future<int> _getTotalSessions() async {
    final val = await _storage.read(key: _keyTotalSessions);
    return int.tryParse(val ?? '0') ?? 0;
  }
}
