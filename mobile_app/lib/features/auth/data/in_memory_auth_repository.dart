import 'dart:async';

import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

/// Test/demo adapter used when [HealthPocketApp] is pumped without Firebase.
class InMemoryAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;
  final Map<String, String> _passwords = {};
  final Map<String, String> _names = {};

  @override
  AuthUser? get currentUser => _user;

  @override
  String? get currentUserId => _user?.uid;

  @override
  Future<bool> hasActiveSession() async => _user != null;

  @override
  Future<AuthUser?> restoreSession() async => _user;

  @override
  Stream<AuthUser?> watchUser() => _controller.stream;

  @override
  Future<AuthResult?> signInWithGoogle() async {
    _user = const AuthUser(
      uid: 'demo-user',
      email: 'amara@example.com',
      displayName: 'Amara Okafor',
      emailVerified: true,
      providers: {AppAuthProvider.google},
    );
    _controller.add(_user);
    return AuthResult(user: _user!, isNewUser: false);
  }

  @override
  Future<AuthResult> createAccountWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (_passwords.containsKey(key)) {
      throw const AuthFailure('An account with this email already exists.');
    }
    _passwords[key] = password;
    _names[key] = name.trim();
    _user = AuthUser(
      uid: key,
      email: key,
      displayName: name.trim(),
      emailVerified: false,
      providers: const {AppAuthProvider.password},
    );
    _controller.add(_user);
    return AuthResult(user: _user!, isNewUser: true);
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final key = email.trim().toLowerCase();
    if (_passwords[key] != password) {
      throw const AuthFailure('Email or password is incorrect.');
    }
    _user = AuthUser(
      uid: key,
      email: key,
      displayName: _names[key],
      emailVerified: true,
      providers: const {AppAuthProvider.password},
    );
    _controller.add(_user);
    return AuthResult(user: _user!, isNewUser: false);
  }

  @override
  Future<AuthUser?> refreshCurrentUser() async => _user;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String password,
  }) async {}

  @override
  Future<bool> reauthenticateWithGoogle() async => true;

  @override
  Future<bool> reauthenticateWithEmail(String password) async =>
      _user != null && _passwords[_user!.email] == password;

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
