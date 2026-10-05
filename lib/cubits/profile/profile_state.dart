part of 'profile_cubit.dart';

/// Статус облачной синхронизации на экране профиля.
enum SyncStatus { idle, syncing, success, error, noInternet }

/// Состояние экрана профиля: авторизация, статус синхронизации и последняя ошибка синхронизации.
@immutable
class ProfileState {
  final bool isAuthenticated;
  final SyncStatus syncStatus;
  final Object? syncError;

  const ProfileState({
    required this.isAuthenticated,
    this.syncStatus = SyncStatus.idle,
    this.syncError,
  });

  /// Возвращает копию состояния. `syncError` сбрасывается, если не передан явно.
  ProfileState copyWith({
    bool? isAuthenticated,
    SyncStatus? syncStatus,
    Object? syncError,
  }) {
    return ProfileState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError,
    );
  }
}
