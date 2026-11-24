import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

typedef FcmTopicAction = Future<void> Function(String topic);

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final FcmTopicAction _subscribeToTopic;
  final FcmTopicAction _unsubscribeFromTopic;

  AuthBloc({
    required this.authRepository,
    FcmTopicAction? subscribeToTopic,
    FcmTopicAction? unsubscribeFromTopic,
  })  : _subscribeToTopic =
            subscribeToTopic ?? FirebaseMessaging.instance.subscribeToTopic,
        _unsubscribeFromTopic = unsubscribeFromTopic ??
            FirebaseMessaging.instance.unsubscribeFromTopic,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<ProfileRefreshRequested>(_onProfileRefreshRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(
        event.username.trim(),
        event.password,
      );
      await _syncFcmTopic(user);
      emit(AuthSuccess('Login Berhasil!', user: user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.register(
        event.name.trim(),
        event.username.trim(),
        event.password,
      );
      emit(const RegisterSuccess('Registrasi Berhasil, Silakan Login'));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final hasToken = await authRepository.hasToken();
      if (!hasToken) {
        emit(AuthUnauthenticated());
        return;
      }

      final user = await authRepository.getProfile().timeout(
            const Duration(seconds: 8),
          );
      await _syncFcmTopic(user);
      emit(AuthSuccess('Selamat Datang Kembali', user: user));
    } catch (e) {
      debugPrint('Auto-login error: $e');
      // Keep cached session on network failure; HTTP 401 already cleared token.
      try {
        if (await authRepository.hasToken()) {
          final cachedUser = await authRepository.getCachedUser();
          if (cachedUser != null) {
            emit(AuthSuccess('Mode offline', user: cachedUser));
            return;
          }
        }
      } catch (cacheError) {
        debugPrint('Offline cache read error: $cacheError');
      }
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onProfileRefreshRequested(
    ProfileRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await authRepository.getProfile();
      await _syncFcmTopic(user);
      emit(AuthSuccess('Profil diperbarui', user: user));
    } catch (e) {
      debugPrint('Refresh profile error: $e');
      if (state is! AuthSuccess) {
        emit(AuthFailure(e.toString()));
      }
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    final groupId = currentState is AuthSuccess
        ? currentState.user.groupId
        : await authRepository.getGroupId();

    try {
      await _unsubscribeFromTopic('sos_group_$groupId');
    } catch (e) {
      debugPrint('Gagal unsubscribe topik FCM saat logout: $e');
    }

    await authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _syncFcmTopic(UserModel user) async {
    try {
      if (user.isHost) {
        await _subscribeToTopic(user.sosTopic);
        debugPrint('FCM: Host subscribed ke topik ${user.sosTopic}');
      } else {
        await _unsubscribeFromTopic(user.sosTopic);
        debugPrint('FCM: User unsubscribed dari topik ${user.sosTopic}');
      }
    } catch (e) {
      // FCM subscription failure should not block login or dashboard entry.
      debugPrint('FCM topic sync error: $e');
    }
  }
}
