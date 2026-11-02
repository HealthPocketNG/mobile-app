enum AppAuthProvider { google, password }

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    required this.providers,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final Set<AppAuthProvider> providers;

  bool get usesGoogle => providers.contains(AppAuthProvider.google);
  bool get usesPassword => providers.contains(AppAuthProvider.password);
}

class AuthResult {
  const AuthResult({required this.user, required this.isNewUser});

  final AuthUser user;
  final bool isNewUser;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
