import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

abstract final class BackendFailureCodes {
  static const unauthenticated = 'unauthenticated';
  static const permissionDenied = 'permission-denied';
  static const invalidArgument = 'invalid-argument';
  static const notFound = 'not-found';
  static const offline = 'offline';
  static const networkError = 'network-error';
  static const unavailable = 'unavailable';
  static const timeout = 'timeout';
  static const rateLimited = 'rate-limited';
  static const insufficientBalance = 'insufficient-balance';
  static const providerNotFound = 'provider-not-found';
  static const providerInactive = 'provider-inactive';
  static const paymentPending = 'payment-pending';
  static const paymentFailed = 'payment-failed';
  static const idempotencyConflict = 'idempotency-conflict';
  static const verificationFailed = 'verification-failed';
  static const savingsFailed = 'savings-failed';
  static const familyPermissionDenied = 'family-permission-denied';
  static const familyInviteInvalid = 'family-invite-invalid';
  static const internal = 'internal';
}

class BackendFailure implements Exception {
  const BackendFailure({
    required this.code,
    required this.message,
    required this.retryable,
    required this.action,
    this.correlationId,
  });

  final String code;
  final String message;
  final bool retryable;
  final String action;
  final String? correlationId;

  factory BackendFailure.fromCode(String code, {String? correlationId}) {
    final normalized = _normalizeCode(code);
    final definition = _definitions[normalized]!;
    return BackendFailure(
      code: normalized,
      message: definition.message,
      retryable: definition.retryable,
      action: definition.action,
      correlationId: _safeCorrelationId(correlationId),
    );
  }

  @override
  String toString() => message;
}

BackendFailure backendFailureFromCallable({
  required String transportCode,
  Object? details,
}) {
  String code = transportCode;
  String? correlationId;
  if (details is Map) {
    final detailCode = details['code'];
    final detailCorrelationId = details['correlationId'];
    if (detailCode is String) code = detailCode;
    if (detailCorrelationId is String) correlationId = detailCorrelationId;
  }
  return BackendFailure.fromCode(code, correlationId: correlationId);
}

BackendFailure mapBackendFailure(Object error) {
  if (error is BackendFailure) return error;
  if (error is TimeoutException) {
    return BackendFailure.fromCode(BackendFailureCodes.timeout);
  }
  if (error is FirebaseException) {
    return BackendFailure.fromCode(error.code);
  }
  if (error is ArgumentError || error is FormatException || error is RangeError) {
    return BackendFailure.fromCode(BackendFailureCodes.invalidArgument);
  }
  return BackendFailure.fromCode(BackendFailureCodes.internal);
}

Future<T> guardRepository<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } catch (error) {
    throw mapBackendFailure(error);
  }
}

StreamTransformer<T, T> repositoryErrorTransformer<T>() =>
    StreamTransformer<T, T>.fromHandlers(
      handleData: (data, sink) => sink.add(data),
      handleError: (error, stackTrace, sink) =>
          sink.addError(mapBackendFailure(error), stackTrace),
    );

class _FailureDefinition {
  const _FailureDefinition(this.message, this.retryable, this.action);

  final String message;
  final bool retryable;
  final String action;
}

const _definitions = <String, _FailureDefinition>{
  'unauthenticated': _FailureDefinition(
    'Your session has expired. Sign in again.',
    false,
    'sign_in',
  ),
  'permission-denied': _FailureDefinition(
    'You do not have permission to perform this action.',
    false,
    'go_back',
  ),
  'invalid-argument': _FailureDefinition(
    'Check the information provided and try again.',
    false,
    'correct_input',
  ),
  'not-found': _FailureDefinition(
    'The requested record could not be found.',
    false,
    'refresh',
  ),
  'offline': _FailureDefinition(
    'You appear to be offline. Reconnect and try again.',
    true,
    'retry',
  ),
  'network-error': _FailureDefinition(
    'A network error occurred. Check your connection and try again.',
    true,
    'retry',
  ),
  'unavailable': _FailureDefinition(
    'This service is temporarily unavailable. Please try again.',
    true,
    'retry',
  ),
  'timeout': _FailureDefinition(
    'The request is taking longer than expected. Check its status before retrying.',
    true,
    'check_status',
  ),
  'rate-limited': _FailureDefinition(
    'Too many attempts. Please wait before trying again.',
    true,
    'wait_and_retry',
  ),
  'insufficient-balance': _FailureDefinition(
    'Your HealthPocket balance is insufficient for this payment.',
    false,
    'add_money',
  ),
  'provider-not-found': _FailureDefinition(
    'This healthcare provider could not be found.',
    false,
    'choose_provider',
  ),
  'provider-inactive': _FailureDefinition(
    'This healthcare provider is currently unavailable.',
    false,
    'choose_provider',
  ),
  'payment-pending': _FailureDefinition(
    'This payment is still processing. Check its status before retrying.',
    true,
    'check_status',
  ),
  'payment-failed': _FailureDefinition(
    'The payment was not completed. Review the details and try again.',
    true,
    'review_and_retry',
  ),
  'idempotency-conflict': _FailureDefinition(
    'This request key was already used for different details.',
    false,
    'start_new_request',
  ),
  'verification-failed': _FailureDefinition(
    'The supplied details could not be verified.',
    false,
    'review_details',
  ),
  'savings-failed': _FailureDefinition(
    'The savings operation could not be completed.',
    true,
    'review_and_retry',
  ),
  'family-permission-denied': _FailureDefinition(
    'Your Family Pocket role does not allow this action.',
    false,
    'contact_pocket_admin',
  ),
  'family-invite-invalid': _FailureDefinition(
    'This Family Pocket invitation is invalid or no longer available.',
    false,
    'request_new_invite',
  ),
  'internal': _FailureDefinition(
    'Something went wrong. Please try again.',
    true,
    'retry',
  ),
};

const _aliases = <String, String>{
  'firebase_auth/user-disabled': 'permission-denied',
  'user-disabled': 'permission-denied',
  'user-not-found': 'unauthenticated',
  'invalid-user-token': 'unauthenticated',
  'user-token-expired': 'unauthenticated',
  'network-request-failed': 'network-error',
  'network_error': 'network-error',
  'failed-precondition': 'invalid-argument',
  'deadline-exceeded': 'timeout',
  'provider-timeout': 'timeout',
  'verification-timeout': 'timeout',
  'resource-exhausted': 'rate-limited',
  'already-exists': 'idempotency-conflict',
  'cancelled': 'network-error',
  'unknown': 'internal',
  'integrity-error': 'internal',
  'invalid-amount': 'invalid-argument',
  'invalid-cursor': 'invalid-argument',
  'invalid-kind': 'invalid-argument',
  'invalid-state': 'invalid-argument',
  'invalid-transition': 'invalid-argument',
  'missing-provider-reference': 'payment-pending',
  'wallet-not-found': 'not-found',
  'wallet-unavailable': 'unavailable',
  'operation-not-found': 'not-found',
  'provider-failed': 'payment-failed',
  'not-verifiable': 'payment-pending',
  'provider-flow-mismatch': 'provider-inactive',
  'provider-transaction-mismatch': 'payment-failed',
  'account-resolution-failed': 'verification-failed',
  'account-resolution-unavailable': 'unavailable',
  'healthcare-verification-failed': 'verification-failed',
  'healthcare-verification-unavailable': 'unavailable',
  'verification-required': 'verification-failed',
  'plan-not-found': 'not-found',
  'plan-already-exists': 'idempotency-conflict',
  'plan-cancelled': 'savings-failed',
  'not-due': 'savings-failed',
  'duplicate-invite': 'family-invite-invalid',
  'invite-already-created': 'family-invite-invalid',
  'invite-not-found': 'family-invite-invalid',
  'email-not-verified': 'verification-failed',
  'owner-transfer-required': 'family-permission-denied',
  'pocket-closed': 'family-permission-denied',
  'already-member': 'family-invite-invalid',
  'already-reversed': 'idempotency-conflict',
  'token-conflict': 'idempotency-conflict',
  'invalid-signature': 'permission-denied',
  'invalid-webhook': 'invalid-argument',
  'provider-reference-conflict': 'idempotency-conflict',
  'provider-reference-mismatch': 'payment-failed',
  'invalid-bank-details': 'verification-failed',
  'not-implemented': 'unavailable',
  'receipt-not-eligible': 'invalid-argument',
};

String _normalizeCode(String code) {
  final stripped = code.contains('/') ? code.split('/').last : code;
  if (_definitions.containsKey(stripped)) return stripped;
  return _aliases[code] ?? _aliases[stripped] ?? BackendFailureCodes.internal;
}

String? _safeCorrelationId(String? value) {
  if (value == null || value.length > 64) return null;
  return RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(value) ? value : null;
}
