enum SavingsGoalStatus { active, paused, completed }

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.frequency,
    required this.status,
  });

  final String id;
  final String title;
  final int targetAmount;
  final int currentAmount;
  final String frequency;
  final SavingsGoalStatus status;

  double get progress => targetAmount == 0 ? 0 : currentAmount / targetAmount;

  SavingsGoal copyWith({
    String? title,
    int? targetAmount,
    int? currentAmount,
    String? frequency,
    SavingsGoalStatus? status,
  }) {
    return SavingsGoal(
      id: id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      frequency: frequency ?? this.frequency,
      status: status ?? this.status,
    );
  }
}

class SavingsContribution {
  const SavingsContribution({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String goalId;
  final String goalTitle;
  final int amount;
  final DateTime createdAt;
}
