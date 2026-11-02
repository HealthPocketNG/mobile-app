import 'package:cloud_functions/cloud_functions.dart';
import 'package:healthpocket/features/auth/domain/email_verification_service.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

class FirebaseEmailVerificationService implements EmailVerificationService {
  FirebaseEmailVerificationService(this.functions);

  final FirebaseFunctions functions;

  @override
  Future<EmailVerificationChallenge> requestChallenge({
    required String authenticatedUserId,
  }) async {
    try {
      final result = await functions
          .httpsCallable('requestEmailVerificationCode')
          .call<Map<String, dynamic>>();
      final data = result.data;
      return EmailVerificationChallenge(
        challengeId: authenticatedUserId,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          data['expiresAt'] as int,
        ),
        resendAvailableAt: DateTime.fromMillisecondsSinceEpoch(
          data['resendAvailableAt'] as int,
        ),
        attemptsRemaining: 5,
      );
    } on FirebaseFunctionsException catch (error) {
      throw AuthFailure(
        error.code == 'resource-exhausted'
            ? 'Please wait before requesting another code.'
            : 'We could not send your code. Check your connection and try again.',
        code: error.code,
      );
    }
  }

  @override
  Future<EmailVerificationOutcome> verifyChallenge({
    required String authenticatedUserId,
    required String challengeId,
    required String code,
  }) async {
    try {
      await functions
          .httpsCallable('verifyEmailCode')
          .call<Map<String, dynamic>>({'code': code});
      return EmailVerificationOutcome.verified;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' ||
          error.code == 'invalid-argument') {
        return EmailVerificationOutcome.invalid;
      }
      throw AuthFailure(
        'We could not verify your code. Check your connection and try again.',
        code: error.code,
      );
    }
  }
}
