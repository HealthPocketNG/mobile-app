import 'package:healthpocket/features/savings/domain/savings_goal.dart';

abstract final class MockSavingsData {
  static const goals = [
    SavingsGoal(
      id: 'family-health-fund',
      title: 'Family Health Fund',
      targetAmount: 150000,
      currentAmount: 42300,
      frequency: 'Monthly',
      status: SavingsGoalStatus.active,
    ),
    SavingsGoal(
      id: 'medicine-buffer',
      title: 'Medicine Buffer',
      targetAmount: 60000,
      currentAmount: 18000,
      frequency: 'Weekly',
      status: SavingsGoalStatus.active,
    ),
  ];

  static final contributions = [
    SavingsContribution(
      id: 'contribution-1',
      goalId: 'family-health-fund',
      goalTitle: 'Family Health Fund',
      amount: 5000,
      createdAt: DateTime.now(),
    ),
    SavingsContribution(
      id: 'contribution-2',
      goalId: 'medicine-buffer',
      goalTitle: 'Medicine Buffer',
      amount: 3000,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
}
