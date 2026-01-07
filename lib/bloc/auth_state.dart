part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

// State khusus jika Login Berhasil (Ada Token/Session)
class AuthSuccess extends AuthState {
  final String message;
  final String role; 

  const AuthSuccess(this.message, {this.role = 'user'});

  @override
  List<Object> get props => [message, role];
}

// [BARU] State khusus jika Register Berhasil (Belum Login/Belum ada session)
class RegisterSuccess extends AuthState {
  final String message;
  const RegisterSuccess(this.message);

  @override
  List<Object> get props => [message];
}

class AuthFailure extends AuthState {
  final String error;
  const AuthFailure(this.error);
  @override
  List<Object> get props => [error];
}