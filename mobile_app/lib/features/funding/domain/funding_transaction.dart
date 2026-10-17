enum FundingTransactionStatus {
  created,
  pending,
  completed,
  failed,
  cancelled,
  reversed,
}

class FundingTransaction {
  const FundingTransaction({
    required this.id,
    required this.userId,
    required this.paymentAttemptId,
    required this.amountKobo,
    required this.currency,
    required this.status,
    required this.provider,
    required this.transactionReference,
    required this.description,
    required this.channel,
    required this.createdAt,
    required this.updatedAt,
    this.providerReference,
    this.ledgerOperationId,
    this.failureCode,
    this.receiptNumber,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String paymentAttemptId;
  final int amountKobo;
  final String currency;
  final FundingTransactionStatus status;
  final String provider;
  final String? providerReference;
  final String? ledgerOperationId;
  final String? failureCode;
  final String transactionReference;
  final String? receiptNumber;
  final String description;
  final String channel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get hasReceipt =>
      status == FundingTransactionStatus.completed && receiptNumber != null;
}

/// Authoritative Add Money limits are repeated in the trusted Node service.
/// These client constants provide immediate validation only; the backend still
/// validates every request independently.
abstract final class FundingAmountPolicy {
  static const int minimumAmountKobo = 50000;
  static const int maximumAmountKobo = 100000000;
  static const List<int> presetAmountsKobo = [
    50000,
    100000,
    200000,
    500000,
    1000000,
  ];

  static bool isValidKobo(int amountKobo) =>
      amountKobo >= minimumAmountKobo && amountKobo <= maximumAmountKobo;
}
