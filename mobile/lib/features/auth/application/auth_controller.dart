import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_auth_interceptor.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../delivery/application/delivery_providers.dart' show restDioProvider;
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Dio for Supabase Auth (GoTrue) — sign-in, sign-out, current-user checks.
/// Shares the same [SupabaseAuthInterceptor]/[SupabaseTokenRefresher] wiring
/// as the app's other Supabase Dio clients, so a session this establishes is
/// immediately visible to them (and vice versa).
final authDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.authBaseUrl,
    connectTimeout: AppConfig.connectTimeout,
    receiveTimeout: AppConfig.receiveTimeout,
    headers: {'Accept': 'application/json', 'apikey': AppConfig.supabaseAnonKey},
  ));
  SupabaseAuthInterceptor(
    storage: ref.watch(supabaseSessionStorageProvider),
    refresher: ref.watch(supabaseTokenRefresherProvider),
  ).attachTo(dio);
  return dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authDioProvider),
    ref.watch(restDioProvider),
    ref.watch(supabaseSessionStorageProvider),
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
  AuthController(this._repository, SupabaseTokenRefresher refresher)
      : super(const AuthState()) {
    // A dead refresh token (expired/revoked, not just momentarily stale)
    // should drop the app back to the login screen right away instead of
    // leaving it authenticated-but-broken until the next restart.
    refresher.onSignedOut = _onRefreshFailed;
    _restore();
  }

  final AuthRepository _repository;

  Future<void> _onRefreshFailed() async {
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

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
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(supabaseTokenRefresherProvider),
  );
});
