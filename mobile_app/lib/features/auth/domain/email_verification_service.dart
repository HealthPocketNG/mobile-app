/// Policy for a future HealthPocket-specific email confirmation flow.
///
/// The Google-only MVP does not need a second code: Firebase Authentication's
/// verified Google identity is authoritative. Any future implementation of
/// this contract must live on a trusted backend, store only a salted code
/// digest, and update verification state server-side after successful use.
class EmailVerificationPolicy {
  const EmailVerificationPolicy({
    this.codeLifetime = const Duration(minutes: 10),
    this.resendCooldown = const Duration(seconds: 60),
    this.maximumAttempts = 5,
    this.maximumRequestsPerHour = 5,
  });

  final Duration codeLifetime;
  final Duration resendCooldown;
  final int maximumAttempts;
  final int maximumRequestsPerHour;
}

class EmailVerificationChallenge {
  const EmailVerificationChallenge({
    required this.challengeId,
    required this.expiresAt,
    required this.resendAvailableAt,
    required this.attemptsRemaining,
  });

  /// Opaque identifier only. The plaintext code is never returned or stored.
  final String challengeId;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;
  final int attemptsRemaining;
}

enum EmailVerificationOutcome {
  verified,
  invalid,
  expired,
  alreadyUsed,
  attemptLimitReached,
  rateLimited,
}

abstract interface class EmailVerificationService {
  Future<EmailVerificationChallenge> requestChallenge({
    required String authenticatedUserId,
  });

  /// The backend consumes a successful challenge atomically so it is
  /// single-use. A client result must never directly set a verified flag.
  Future<EmailVerificationOutcome> verifyChallenge({
    required String authenticatedUserId,
    required String challengeId,
    required String code,
  });
}
