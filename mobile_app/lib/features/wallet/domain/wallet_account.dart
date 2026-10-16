enum WalletStatus { active, restricted, closed }

enum LedgerDirection { credit, debit }

enum LedgerEntryStatus { completed, reversed }

enum FinancialOperationStatus {
  pending,
  completed,
  failed,
  reversed,
  cancelled,
}

enum FinancialSource {
  funding('funding'),
  savingsContribution('savings_contribution'),
  familyContribution('family_contribution'),
  healthcarePayment('healthcare_payment'),
  reversal('reversal'),
  adjustment('adjustment'),
  mock('mock');

  const FinancialSource(this.firestoreValue);

  final String firestoreValue;

  static FinancialSource fromFirestore(String value) => values.firstWhere(
    (source) => source.firestoreValue == value,
    orElse: () => throw FormatException('Unknown financial source "$value".'),
  );
}

/// Read-only client representation of the server-owned wallet cache.
class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.userId,
    required this.currency,
    required this.availableBalanceKobo,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String currency;
  final int availableBalanceKobo;
  final WalletStatus status;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// An immutable, server-created posting. Reversals are separate entries.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.operationId,
    required this.userId,
    required this.walletId,
    required this.direction,
    required this.amountKobo,
    required this.currency,
    required this.status,
    required this.source,
    required this.createdAt,
    this.providerReference,
    this.familyPocketId,
    this.reversesLedgerEntryId,
  });

  final String id;
  final String operationId;
  final String userId;
  final String walletId;
  final LedgerDirection direction;
  final int amountKobo;
  final String currency;
  final LedgerEntryStatus status;
  final FinancialSource source;
  final DateTime createdAt;
  final String? providerReference;
  final String? familyPocketId;
  final String? reversesLedgerEntryId;

  int get signedAmountKobo =>
      direction == LedgerDirection.credit ? amountKobo : -amountKobo;
}

class FinancialOperation {
  const FinancialOperation({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.direction,
    required this.amountKobo,
    required this.currency,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.ledgerEntryId,
    this.failureCode,
    this.providerReference,
    this.familyPocketId,
  });

  final String id;
  final String userId;
  final String walletId;
  final LedgerDirection direction;
  final int amountKobo;
  final String currency;
  final FinancialOperationStatus status;
  final FinancialSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? ledgerEntryId;
  final String? failureCode;
  final String? providerReference;
  final String? familyPocketId;
}
