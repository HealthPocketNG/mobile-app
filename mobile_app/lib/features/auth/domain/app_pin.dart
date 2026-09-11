class PinVerificationResult {
  const PinVerificationResult._({
    required this.isValid,
    required this.remainingAttempts,
    this.lockedUntil,
  });

  const PinVerificationResult.valid()
    : this._(isValid: true, remainingAttempts: 5);

  const PinVerificationResult.invalid(int remainingAttempts)
    : this._(isValid: false, remainingAttempts: remainingAttempts);

  const PinVerificationResult.locked(DateTime lockedUntil)
    : this._(isValid: false, remainingAttempts: 0, lockedUntil: lockedUntil);

  final bool isValid;
  final int remainingAttempts;
  final DateTime? lockedUntil;

  bool get isLocked => lockedUntil != null;
}
