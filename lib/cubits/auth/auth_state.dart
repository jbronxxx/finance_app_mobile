part of 'auth_cubit.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class Authenticated extends AuthState {
  final String email;
  final String name;

  Authenticated({required this.email, required this.name});
}

class Unauthenticated extends AuthState {}
