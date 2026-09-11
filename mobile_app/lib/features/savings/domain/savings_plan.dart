enum SavingsPlanStatus { active, paused }

enum SavingsFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const SavingsFrequency(this.label);

  final String label;
}

class SavingsPlan {
  const SavingsPlan({
    required this.id,
    required this.contributionAmount,
    required this.frequency,
    required this.startDate,
    required this.status,
  });

  final String id;
  final int contributionAmount;
  final SavingsFrequency frequency;
  final DateTime startDate;
  final SavingsPlanStatus status;

  SavingsPlan copyWith({
    int? contributionAmount,
    SavingsFrequency? frequency,
    DateTime? startDate,
    SavingsPlanStatus? status,
  }) {
    return SavingsPlan(
      id: id,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
    );
  }
}

enum SavingsContributionStatus { completed, reversed }

class SavingsContribution {
  const SavingsContribution({
    required this.id,
    required this.planId,
    required this.amount,
    required this.createdAt,
    this.status = SavingsContributionStatus.completed,
    this.source = 'mock',
  });

  final String id;
  final String planId;
  final int amount;
  final DateTime createdAt;
  final SavingsContributionStatus status;
  final String source;
}
