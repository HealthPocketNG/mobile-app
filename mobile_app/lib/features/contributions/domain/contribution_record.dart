enum ContributionStatus { recorded, reversed }

enum ContributionOrigin {
  devSimulation('dev_simulation');

  const ContributionOrigin(this.firestoreValue);

  final String firestoreValue;

  static ContributionOrigin fromFirestore(String value) => values.firstWhere(
    (origin) => origin.firestoreValue == value,
    orElse: () =>
        throw FormatException('Unknown contribution origin "$value".'),
  );
}

class ContributionRecord {
  const ContributionRecord({
    required this.id,
    required this.contributorUserId,
    required this.amountKobo,
    required this.currency,
    required this.status,
    required this.origin,
    required this.moneyMovement,
    required this.idempotencyKey,
    required this.createdAt,
    this.personalHealthPocketId,
    this.savingsPlanId,
    this.familyPocketId,
    this.contributorName,
    this.note,
  }) : assert(
         (personalHealthPocketId == null) != (familyPocketId == null),
         'A contribution must belong to exactly one pocket.',
       );

  final String id;
  final String contributorUserId;
  final String? personalHealthPocketId;
  final String? savingsPlanId;
  final String? familyPocketId;
  final String? contributorName;

  /// Monetary values are stored as integer kobo. Never pass naira here.
  final int amountKobo;
  final String currency;
  final ContributionStatus status;
  final ContributionOrigin origin;
  final bool moneyMovement;
  final String idempotencyKey;
  final String? note;
  final DateTime? createdAt;

  bool get isEligibleForDevelopmentBalance =>
      personalHealthPocketId != null &&
      status == ContributionStatus.recorded &&
      origin == ContributionOrigin.devSimulation &&
      !moneyMovement &&
      currency == 'NGN' &&
      amountKobo > 0;
}
