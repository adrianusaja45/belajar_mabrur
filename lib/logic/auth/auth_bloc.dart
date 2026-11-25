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
      emit(AuthSuccess('Berhasil masuk.', user: user));
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
      emit(const RegisterSuccess('Pendaftaran berhasil. Silakan masuk.'));
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
      emit(AuthSuccess('Selamat datang kembali.', user: user));
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
      emit(AuthSuccess('Profil berhasil diperbarui.', user: user));
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
    final groupId = UserModel.normalizeGroupId(
      currentState is AuthSuccess
          ? currentState.user.groupId
          : await authRepository.getGroupId(),
    );
    final lastTopic = await authRepository.getLastSubscribedSosTopic();
    final topicsToUnsubscribe = <String>{
      if (lastTopic != null) lastTopic,
      if (groupId.isNotEmpty) 'sos_group_$groupId',
    };

    var unsubscribedAll = true;
    for (final topic in topicsToUnsubscribe) {
      try {
        await _unsubscribeFromTopic(topic);
      } catch (e) {
        unsubscribedAll = false;
        debugPrint('Gagal unsubscribe topik FCM $topic saat logout: $e');
      }
    }
    if (unsubscribedAll) {
      await authRepository.setLastSubscribedSosTopic(null);
    }

    await authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _syncFcmTopic(UserModel user) async {
    final targetTopic = (user.isHost && user.hasGroup) ? user.sosTopic : null;
    final lastTopic = await authRepository.getLastSubscribedSosTopic();

    try {
      if (lastTopic != null && lastTopic != targetTopic) {
        await _unsubscribeFromTopic(lastTopic);
        await authRepository.setLastSubscribedSosTopic(null);
        debugPrint('FCM: Unsubscribed dari topik lama $lastTopic');
      }

      if (targetTopic != null) {
        await _subscribeToTopic(targetTopic);
        await authRepository.setLastSubscribedSosTopic(targetTopic);
        debugPrint('FCM: Host subscribed ke topik $targetTopic');
      } else if (user.hasGroup && user.sosTopic != lastTopic) {
        await _unsubscribeFromTopic(user.sosTopic);
        debugPrint('FCM: User unsubscribed dari topik ${user.sosTopic}');
      }
    } catch (e) {
      // FCM subscription failure should not block login or dashboard entry.
      debugPrint('FCM topic sync error: $e');
    }
  }
}
