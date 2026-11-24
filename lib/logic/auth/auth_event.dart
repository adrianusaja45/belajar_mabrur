part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class LoginRequested extends AuthEvent {
  final String username;
  final String password;

  const LoginRequested(this.username, this.password);

  @override
  List<Object> get props => [username, password];
}

class RegisterRequested extends AuthEvent {
  final String name;
  final String username;
  final String password;

  const RegisterRequested(this.name, this.username, this.password);

  @override
  List<Object> get props => [name, username, password];
}

class CheckAuthStatus extends AuthEvent {}

class ProfileRefreshRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}
