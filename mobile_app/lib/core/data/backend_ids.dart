import 'dart:math';

/// Canonical Firestore identifier policy for HealthPocket-owned documents.
///
/// Firebase Auth UIDs remain the identity authority. Application-generated IDs
/// use only URL/path-safe ASCII characters and an unpredictable 128-bit token.
abstract final class BackendIds {
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,256}$');
  static final RegExp _userId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _requestKey = RegExp(r'^[A-Za-z0-9_-]{16,80}$');

  static bool isSafe(String value) => _safeId.hasMatch(value);

  static String requireSafe(String value, {String name = 'id'}) {
    if (!isSafe(value)) {
      throw ArgumentError.value(value, name, 'Use 1–256 path-safe characters.');
    }
    return value;
  }

  static String requireRequestKey(String value) {
    if (!_requestKey.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'idempotencyKey',
        'Use 16–80 path-safe characters.',
      );
    }
    return value;
  }

  static String requireUserId(String value) {
    if (!_userId.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'userId',
        'Use a valid Firebase UID with at most 128 path-safe characters.',
      );
    }
    return value;
  }

  static String personalPocket(String userId) =>
      'personal-${requireUserId(userId)}';

  static String savingsPlan(String userId) =>
      'personal-plan-${requireUserId(userId)}';

  static String familyPocket(String userId) =>
      'family_${requireUserId(userId)}_${newRequestKey()}';

  static bool isFamilyPocketForUser(String value, String userId) => RegExp(
    '^family_${RegExp.escape(requireUserId(userId))}_[A-Fa-f0-9]{32}\$',
  ).hasMatch(value);

  static String invitation(String userId) =>
      'invite_${requireUserId(userId)}_${newRequestKey()}';

  static bool isInvitationForUser(String value, String userId) => RegExp(
    '^invite_${RegExp.escape(requireUserId(userId))}_[A-Fa-f0-9]{32}\$',
  ).hasMatch(value);

  static String personalContribution(String userId, String requestKey) =>
      'dev_${requireUserId(userId)}_${requireRequestKey(requestKey)}';

  static String familyContribution(String userId, String requestKey) =>
      'dev_family_${requireUserId(userId)}_${requireRequestKey(requestKey)}';

  static String newRequestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
