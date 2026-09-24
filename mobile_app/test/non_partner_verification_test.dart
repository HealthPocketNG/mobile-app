import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/care/data/mock_non_partner_verification_services.dart';
import 'package:healthpocket/features/care/domain/non_partner_verification.dart';

void main() {
  test(
    'bank resolution and healthcare verification stay behind services',
    () async {
      const accounts = MockBankAccountVerificationService();
      const merchants = MockHealthcareMerchantVerificationService();
      final recipient = await accounts.resolveAccount(
        accountNumber: '0123456789',
        bankCode: '044',
      );
      final result = await merchants.verifyRecipient(
        providerId: 'demo_hospital_001',
        recipient: recipient,
      );

      expect(recipient.accountName, 'Verified Healthcare Recipient');
      expect(result.status, MerchantVerificationStatus.verified);
      expect(result.source, 'beta_mock');
    },
  );

  test('account resolution rejects malformed account numbers', () {
    expect(
      () => const MockBankAccountVerificationService().resolveAccount(
        accountNumber: '123',
        bankCode: '044',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
