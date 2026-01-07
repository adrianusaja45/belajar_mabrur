part of 'auth_bloc.dart';

/// Base class state autentikasi.
abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object> get props => [];
}

/// State awal saat belum ada aksi apa-apa.
class AuthInitial extends AuthState {}

/// State ketika proses (API call) sedang berjalan.
/// UI biasanya menampilkan CircularProgressIndicator.
class AuthLoading extends AuthState {}

/// State KHUSUS Login/Cek Status Berhasil (User punya sesi).
class AuthSuccess extends AuthState {
  final String message;
  final String role; // 'host' atau 'user'

  const AuthSuccess(this.message, {this.role = 'user'});

  @override
  List<Object> get props => [message, role];
}

/// State KHUSUS Register Berhasil.
/// Dibedakan agar UI tidak langsung masuk ke Dashboard, tapi ke Login screen dulu.
class RegisterSuccess extends AuthState {
  final String message;
  const RegisterSuccess(this.message);

  @override
  List<Object> get props => [message];
}

/// State ketika terjadi error (Password salah, Server down, dll).
class AuthFailure extends AuthState {
  final String error;
  const AuthFailure(this.error);

  @override
  List<Object> get props => [error];
}