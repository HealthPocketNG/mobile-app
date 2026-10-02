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
  Future<bool> reauthenticateWithGoogle() async => true;

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
