import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/funding/domain/funding_transaction.dart';

void main() {
  test('Add Money policy exposes presets and accepts valid custom amounts', () {
    expect(FundingAmountPolicy.presetAmountsKobo, [
      50000,
      100000,
      200000,
      500000,
      1000000,
    ]);
    expect(FundingAmountPolicy.isValidKobo(50000), isTrue);
    expect(FundingAmountPolicy.isValidKobo(123456), isTrue);
    expect(FundingAmountPolicy.isValidKobo(49999), isFalse);
    expect(FundingAmountPolicy.isValidKobo(100000001), isFalse);
  });

  test('a receipt is available only for a completed transaction', () {
    FundingTransaction build({
      required FundingTransactionStatus status,
      String? receiptNumber,
    }) => FundingTransaction(
      id: 'pay-1',
      userId: 'user-1',
      paymentAttemptId: 'pay-1',
      amountKobo: 50000,
      currency: 'NGN',
      status: status,
      provider: 'mock',
      transactionReference: 'pay-1',
      receiptNumber: receiptNumber,
      description: 'HealthPocket wallet funding',
      channel: 'mock',
      createdAt: DateTime.utc(2026, 10, 17),
      updatedAt: DateTime.utc(2026, 10, 17),
    );

    expect(
      build(
        status: FundingTransactionStatus.completed,
        receiptNumber: 'HPF-ABCDEF123456',
      ).hasReceipt,
      isTrue,
    );
    expect(build(status: FundingTransactionStatus.pending).hasReceipt, isFalse);
  });
}
