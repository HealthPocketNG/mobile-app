import 'dart:async';

import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

/// Local UI preview only. It never creates a Firebase user or token.
class PreviewAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  String? _password;

  @override
  AuthUser? get currentUser => _user;

  @override
  String? get currentUserId => _user?.uid;

  @override
  Stream<AuthUser?> watchUser() => _changes.stream;

  @override
  Future<AuthUser?> restoreSession() async => _user;

  @override
  Future<bool> hasActiveSession() async => _user != null;

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized) ||
        password.length < 8) {
      throw const AuthFailure(
        'Enter a valid email and an 8-character password.',
      );
    }
    _password = password;
    _user = AuthUser(
      uid: 'local-preview',
      email: normalized,
      displayName: 'David',
      emailVerified: true,
      providers: const {AppAuthProvider.password},
    );
    _changes.add(_user);
    return AuthResult(user: _user!, isNewUser: false);
  }

  @override
  Future<AuthResult?> signInWithGoogle() async => throw const AuthFailure(
    'Google sign-in is unavailable in local preview.',
  );

  @override
  Future<AuthResult> createAccountWithEmail({
    required String name,
    required String email,
    required String password,
  }) async => throw const AuthFailure(
    'Account creation is unavailable in local preview.',
  );

  @override
  Future<AuthUser?> refreshCurrentUser() async => _user;

  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      throw const AuthFailure(
        'Password reset is unavailable in local preview.',
      );

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String password,
  }) async => throw const AuthFailure(
    'Password reset is unavailable in local preview.',
  );

  @override
  Future<bool> reauthenticateWithGoogle() async => false;

  @override
  Future<bool> reauthenticateWithEmail(String password) async =>
      _user != null && _password == password;

  @override
  Future<void> signOut() async {
    _user = null;
    _password = null;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
