import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/domain/savings_schedule.dart';

void main() {
  test('daily and weekly schedules preserve the UTC contribution time', () {
    final start = DateTime.utc(2026, 1, 31, 9, 30);

    expect(
      SavingsSchedule.nextContributionDate(
        startDate: start,
        frequency: SavingsFrequency.daily,
        after: DateTime.utc(2026, 2, 2, 9, 29),
      ),
      DateTime.utc(2026, 2, 2, 9, 30),
    );
    expect(
      SavingsSchedule.nextContributionDate(
        startDate: start,
        frequency: SavingsFrequency.weekly,
        after: DateTime.utc(2026, 2, 7, 9, 31),
      ),
      DateTime.utc(2026, 2, 14, 9, 30),
    );
  });

  test('monthly schedules clamp safely to the last calendar day', () {
    expect(
      SavingsSchedule.nextContributionDate(
        startDate: DateTime.utc(2026, 1, 31, 9, 30),
        frequency: SavingsFrequency.monthly,
        after: DateTime.utc(2026, 2, 1),
      ),
      DateTime.utc(2026, 2, 28, 9, 30),
    );
  });
}
