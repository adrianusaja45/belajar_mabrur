part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String message;
  final UserModel user;

  const AuthSuccess(this.message, {required this.user});

  String get role => user.role;

  @override
  List<Object> get props => [message, user];
}

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
