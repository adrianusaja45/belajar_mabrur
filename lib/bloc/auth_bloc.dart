import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    
    // Di dalam class AuthBloc
on<LoginRequested>((event, emit) async {
  emit(AuthLoading());
  try {
    // Tambahkan timeout 10 detik untuk proses login
    final result = await authRepository.login(event.username, event.password).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception("Server tidak merespons. Cek koneksi Anda."),
    );
    
    final String role = result['data']['user']['role'] ?? 'user';
    emit(AuthSuccess("Login Berhasil!", role: role));
  } catch (e) {
    emit(AuthFailure(e.toString()));
  }
});

on<RegisterRequested>((event, emit) async {
  emit(AuthLoading());
  try {
    // Tambahkan timeout untuk proses registrasi
    await authRepository.register(event.name, event.username, event.password).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception("Gagal mendaftar. Silakan coba lagi."),
    );
    
    emit(const AuthSuccess("Registrasi Berhasil, Silakan Login", role: 'user'));
  } catch (e) {
    emit(AuthFailure(e.toString()));
  }
});

    on<CheckAuthStatus>((event, emit) async {
  // Gunakan timeout agar tidak loading selamanya
  try {
    final hasToken = await authRepository.hasToken();
    if (hasToken) {
      // Tambahkan timeout 5 detik untuk validasi profil
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
    // Jika error/timeout, paksa ke halaman login agar tidak hang
    emit(AuthInitial()); 
  }
});

    on<LogoutRequested>((event, emit) async {
      await authRepository.logout();
      emit(AuthInitial());
    });

  }
}