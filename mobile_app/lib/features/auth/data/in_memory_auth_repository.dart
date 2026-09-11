import 'dart:async';

import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

/// Test/demo adapter used when [HealthPocketApp] is pumped without Firebase.
class InMemoryAuthRepository implements AuthRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  String? get currentUserId => _user?.uid;

  @override
  Future<bool> hasActiveSession() async => _user != null;

  @override
  Stream<AuthUser?> watchUser() => _controller.stream;

  @override
  Future<AuthResult> createAccountWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _user = AuthUser(
      uid: 'demo-user',
      email: email,
      displayName: fullName,
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
    _user = AuthUser(
      uid: 'demo-user',
      email: email,
      displayName: 'HealthPocket User',
      emailVerified: true,
      providers: const {AppAuthProvider.password},
    );
    _controller.add(_user);
    return AuthResult(user: _user!, isNewUser: false);
  }

  @override
  Future<AuthResult?> signInWithGoogle() async {
    _user = const AuthUser(
      uid: 'demo-google-user',
      email: 'user@example.com',
      displayName: 'HealthPocket User',
      emailVerified: true,
      providers: {AppAuthProvider.google},
    );
    _controller.add(_user);
    return AuthResult(user: _user!, isNewUser: false);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async => _user;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<bool> reauthenticateWithGoogle() async => true;

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void markEmailVerified() {
    final user = _user;
    if (user == null) return;
    _user = AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      emailVerified: true,
      providers: user.providers,
    );
    _controller.add(_user);
  }

  void dispose() => _controller.close();
}
