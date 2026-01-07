part of 'auth_bloc.dart';

/// Base class untuk semua event autentikasi.
/// Menggunakan Equatable agar perbandingan object lebih efisien.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

/// Event ketika tombol Login ditekan.
class LoginRequested extends AuthEvent {
  final String username;
  final String password;
  const LoginRequested(this.username, this.password);

  @override
  List<Object> get props => [username, password];
}

/// Event ketika tombol Register ditekan.
class RegisterRequested extends AuthEvent {
  final String name;
  final String username;
  final String password;
  const RegisterRequested(this.name, this.username, this.password);

  @override
  List<Object> get props => [name, username, password];
}

/// Event otomatis saat aplikasi baru dibuka (Splash Screen)
/// untuk mengecek apakah user masih login atau tidak.
class CheckAuthStatus extends AuthEvent {}

/// Event ketika tombol Logout ditekan.
class LogoutRequested extends AuthEvent {}