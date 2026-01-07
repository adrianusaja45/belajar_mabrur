import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/auth_repository.dart';

// Menghubungkan file part agar bisa saling akses private variable/class
part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    
    // --- HANDLER: LOGIN ---
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading()); // Ubah UI jadi loading
      try {
        // Panggil Repository dengan timeout 10 detik
        final result = await authRepository.login(event.username, event.password).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Server tidak merespons. Cek koneksi Anda."),
        );
        
        final String role = result['data']['user']['role'] ?? 'user';
        // Emit Sukses dengan membawa Role user
        emit(AuthSuccess("Login Berhasil!", role: role));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    // --- HANDLER: REGISTER ---
    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.register(event.name, event.username, event.password).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Gagal mendaftar. Silakan coba lagi."),
        );
        
        // Emit RegisterSuccess (UI akan arahkan ke Login, bukan Dashboard)
        emit(const RegisterSuccess("Registrasi Berhasil, Silakan Login"));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    // --- HANDLER: CEK STATUS (AUTO LOGIN) ---
    on<CheckAuthStatus>((event, emit) async {
      try {
        final hasToken = await authRepository.hasToken();
        if (hasToken) {
          // Jika token ada, ambil profil terbaru untuk cek Role & Group ID
          final profile = await authRepository.getProfile().timeout(
            const Duration(seconds: 5),
          ); 
          final String role = profile['role'] ?? 'user';
          emit(AuthSuccess("Selamat Datang Kembali", role: role));
        } else {
          // Token tidak ada, user harus login manual
          emit(AuthInitial());
        }
      } catch (e) {
        debugPrint("Auto-login error: $e");
        // Jika token expired atau error, kembalikan ke Initial (Login Screen)
        emit(AuthInitial()); 
      }
    });

    // --- HANDLER: LOGOUT ---
    on<LogoutRequested>((event, emit) async {
      await authRepository.logout();
      emit(AuthInitial()); // UI akan redirect ke Login Screen
    });
  }
}