enum ContributionStatus { recorded, completed, reversed }

enum ContributionSource { mock, manual, provider }

class ContributionRecord {
  ContributionRecord({
    required this.id,
    required this.contributorUserId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.source,
    required this.createdAt,
    this.personalHealthPocketId,
    this.savingsPlanId,
    this.familyPocketId,
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
  final int amount;
  final String currency;
  final ContributionStatus status;
  final ContributionSource source;
  final String? note;
  final DateTime createdAt;
}
