import 'package:healthpocket/features/savings/domain/savings_plan.dart';

abstract final class MockSavingsData {
  static final plan = SavingsPlan(
    id: 'personal-savings-plan',
    contributionAmount: 5000,
    frequency: SavingsFrequency.weekly,
    startDate: DateTime(2026, 9, 1),
    status: SavingsPlanStatus.active,
  );
}
