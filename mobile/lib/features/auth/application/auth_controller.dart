import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.error,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool isSubmitting;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isSubmitting,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, user, isSubmitting, error];
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    _restore();
  }

  final AuthRepository _repository;

  Future<void> _restore() async {
    final result = await _repository.currentUser();
    result.when(
      success: (user) => state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      ),
      failure: (_) => state = state.copyWith(status: AuthStatus.unauthenticated),
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isSubmitting: true, error: null);
    final result = await _repository.login(email, password);
    return result.when(
      success: (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isSubmitting: false,
        );
        return true;
      },
      failure: (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return false;
      },
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
