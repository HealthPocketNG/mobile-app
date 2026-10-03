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
    required this.contributionAmountKobo,
    required this.frequency,
    required this.startDate,
    required this.status,
  });

  final String id;

  /// Scheduled contribution amount in integer kobo.
  final int contributionAmountKobo;
  final SavingsFrequency frequency;
  final DateTime startDate;
  final SavingsPlanStatus status;

  SavingsPlan copyWith({
    int? contributionAmountKobo,
    SavingsFrequency? frequency,
    DateTime? startDate,
    SavingsPlanStatus? status,
  }) {
    return SavingsPlan(
      id: id,
      contributionAmountKobo:
          contributionAmountKobo ?? this.contributionAmountKobo,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
    );
  }
}
