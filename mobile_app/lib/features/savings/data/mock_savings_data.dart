import 'package:healthpocket/features/savings/domain/savings_plan.dart';

abstract final class MockSavingsData {
  static final plan = SavingsPlan(
    id: 'personal-savings-plan',
    contributionAmountKobo: 500000,
    frequency: SavingsFrequency.weekly,
    startDate: DateTime(2026, 9, 1),
    status: SavingsPlanStatus.active,
  );
}
