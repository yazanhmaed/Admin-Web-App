import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isSubmitting = false,
  });

  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isSubmitting;

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? isSubmitting,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

/// يدير حالة تسجيل الدخول ويستمع لتغيّرات Firebase Auth مباشرة.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState.unknown()) {
    _subscription = _authRepository.authStateChanges.listen((user) {
      emit(state.copyWith(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: user,
      ));
    });
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _subscription;

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _authRepository.signIn(email: email, password: password);
      emit(state.copyWith(isSubmitting: false, clearError: true));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: AuthRepository.messageForError(e),
      ));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  Future<void> signOut() => _authRepository.signOut();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
