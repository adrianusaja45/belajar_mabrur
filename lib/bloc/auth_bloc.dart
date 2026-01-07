import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    
    // LOGIN
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final result = await authRepository.login(event.username, event.password).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Server tidak merespons. Cek koneksi Anda."),
        );
        
        final String role = result['data']['user']['role'] ?? 'user';
        // Login tetap pakai AuthSuccess
        emit(AuthSuccess("Login Berhasil!", role: role));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    // REGISTER
    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.register(event.name, event.username, event.password).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Gagal mendaftar. Silakan coba lagi."),
        );
        
        // [UBAH DISINI] Gunakan RegisterSuccess, bukan AuthSuccess
        emit(const RegisterSuccess("Registrasi Berhasil, Silakan Login"));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    // CHECK AUTH
    on<CheckAuthStatus>((event, emit) async {
      try {
        final hasToken = await authRepository.hasToken();
        if (hasToken) {
          final profile = await authRepository.getProfile().timeout(
            const Duration(seconds: 5),
          ); 
          final String role = profile['role'] ?? 'user';
          emit(AuthSuccess("Selamat Datang Kembali", role: role));
        } else {
          emit(AuthInitial());
        }
      } catch (e) {
        debugPrint("Auto-login error: $e");
        emit(AuthInitial()); 
      }
    });

    // LOGOUT
    on<LogoutRequested>((event, emit) async {
      await authRepository.logout();
      emit(AuthInitial());
    });

  }
}