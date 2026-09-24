enum MerchantVerificationStatus { verified, ineligible, unavailable }

class ResolvedBankAccount {
  const ResolvedBankAccount({
    required this.accountNumber,
    required this.bankCode,
    required this.bankName,
    required this.accountName,
  });
  final String accountNumber;
  final String bankCode;
  final String bankName;
  final String accountName;
}

class MerchantVerificationResult {
  const MerchantVerificationResult({
    required this.status,
    required this.reason,
    this.merchantCategory,
    this.mcc,
    this.source = 'beta_mock',
  });
  final MerchantVerificationStatus status;
  final String reason;
  final String? merchantCategory;
  final String? mcc;
  final String source;
  bool get verified => status == MerchantVerificationStatus.verified;
}

abstract interface class BankAccountVerificationService {
  Future<ResolvedBankAccount> resolveAccount({
    required String accountNumber,
    required String bankCode,
  });
}

/// Keeps merchant-category/MCC rules out of the Flutter presentation layer.
abstract interface class HealthcareMerchantVerificationService {
  Future<MerchantVerificationResult> verifyRecipient({
    required String providerId,
    required ResolvedBankAccount recipient,
  });
}
