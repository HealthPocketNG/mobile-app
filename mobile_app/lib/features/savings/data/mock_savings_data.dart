import 'package:healthpocket/features/savings/domain/savings_plan.dart';

abstract final class MockSavingsData {
  static final plan = SavingsPlan(
    id: 'personal-savings-plan',
    contributionAmount: 5000,
    frequency: 'Weekly',
    startDate: DateTime(2026, 9, 1),
    status: SavingsPlanStatus.active,
  );

  static final contributions = [
    SavingsContribution(
      id: 'contribution-1',
      planId: 'personal-savings-plan',
      amount: 7300,
      createdAt: DateTime.now(),
    ),
    SavingsContribution(
      id: 'contribution-2',
      planId: 'personal-savings-plan',
      amount: 15000,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    SavingsContribution(
      id: 'contribution-3',
      planId: 'personal-savings-plan',
      amount: 20000,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];
}
