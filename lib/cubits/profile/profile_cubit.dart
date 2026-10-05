import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';

part 'profile_state.dart';

/// Управляет состоянием авторизации, облачной синхронизацией и выходом из аккаунта.
class ProfileCubit extends Cubit<ProfileState> {
  final ApiService _api;
  final Connectivity _connectivity;
  late final StreamSubscription<bool> _authSubscription;

  ProfileCubit({ApiService? api, Connectivity? connectivity})
      : _api = api ?? ApiService.instance,
        _connectivity = connectivity ?? Connectivity(),
        super(ProfileState(
            isAuthenticated: (api ?? ApiService.instance).isAuthenticated)) {
    _authSubscription = _api.authStream.listen((isAuth) {
      emit(state.copyWith(isAuthenticated: isAuth));
    });
  }

  /// Запускает полную синхронизацию. Ошибка сохраняется в `state.syncError`.
  Future<void> startSync() async {
    if (state.syncStatus == SyncStatus.syncing) return;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (isClosed) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      emit(state.copyWith(syncStatus: SyncStatus.noInternet));
      return;
    }

    emit(state.copyWith(syncStatus: SyncStatus.syncing));

    try {
      await _api.syncAll();
      if (isClosed) return;
      emit(state.copyWith(syncStatus: SyncStatus.success));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(syncStatus: SyncStatus.error, syncError: e));
    }
  }

  /// Отзывает сессию на сервере. Ошибки сервера не прерывают локальный выход:
  /// токены очищаются в [ApiService.logout] в любом случае.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfileCubit] Server logout failed: $e');
    }
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
