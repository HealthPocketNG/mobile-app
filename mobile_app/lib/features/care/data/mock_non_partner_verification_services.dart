import 'package:healthpocket/features/care/domain/non_partner_verification.dart';

class MockBankAccountVerificationService
    implements BankAccountVerificationService {
  const MockBankAccountVerificationService();

  @override
  Future<ResolvedBankAccount> resolveAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!RegExp(r'^\d{10}$').hasMatch(accountNumber)) {
      throw const FormatException('Enter a valid 10-digit account number.');
    }
    const banks = {'044': 'Access Bank', '058': 'GTBank', '033': 'UBA'};
    final bankName = banks[bankCode];
    if (bankName == null) {
      throw const FormatException('Choose a supported bank.');
    }
    return ResolvedBankAccount(
      accountNumber: accountNumber,
      bankCode: bankCode,
      bankName: bankName,
      accountName: 'Verified Healthcare Recipient',
    );
  }
}

class MockHealthcareMerchantVerificationService
    implements HealthcareMerchantVerificationService {
  const MockHealthcareMerchantVerificationService();

  @override
  Future<MerchantVerificationResult> verifyRecipient({
    required String providerId,
    required ResolvedBankAccount recipient,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (providerId.isEmpty) {
      return const MerchantVerificationResult(
        status: MerchantVerificationStatus.unavailable,
        reason: 'We could not verify this provider right now.',
      );
    }
    return const MerchantVerificationResult(
      status: MerchantVerificationStatus.verified,
      reason: 'Recipient verified as a healthcare provider.',
      merchantCategory: 'Healthcare services',
      mcc: 'beta_healthcare',
    );
  }
}
