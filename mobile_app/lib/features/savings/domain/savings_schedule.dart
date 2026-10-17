import 'package:healthpocket/features/savings/domain/savings_plan.dart';

/// Calendar-safe recurring schedule calculation, kept outside presentation.
abstract final class SavingsSchedule {
  static DateTime nextContributionDate({
    required DateTime startDate,
    required SavingsFrequency frequency,
    required DateTime after,
  }) {
    final start = startDate.toUtc();
    final reference = after.toUtc();
    if (!start.isBefore(reference)) return start;

    return switch (frequency) {
      SavingsFrequency.daily => _fixedInterval(start, reference, 1),
      SavingsFrequency.weekly => _fixedInterval(start, reference, 7),
      SavingsFrequency.monthly => _monthly(start, reference),
    };
  }

  static DateTime _fixedInterval(
    DateTime start,
    DateTime reference,
    int days,
  ) {
    final interval = Duration(days: days);
    final elapsedMicroseconds = reference.difference(start).inMicroseconds;
    final intervalMicroseconds = interval.inMicroseconds;
    final steps = (elapsedMicroseconds + intervalMicroseconds - 1) ~/
        intervalMicroseconds;
    return start.add(Duration(microseconds: steps * intervalMicroseconds));
  }

  static DateTime _monthly(DateTime start, DateTime reference) {
    final monthDifference =
        (reference.year - start.year) * 12 + reference.month - start.month;
    var candidate = _addClampedUtcMonths(start, monthDifference);
    if (candidate.isBefore(reference)) {
      candidate = _addClampedUtcMonths(start, monthDifference + 1);
    }
    return candidate;
  }

  static DateTime _addClampedUtcMonths(DateTime start, int months) {
    final zeroBasedMonth = start.month - 1 + months;
    final year = start.year + zeroBasedMonth ~/ 12;
    final month = zeroBasedMonth % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return DateTime.utc(
      year,
      month,
      start.day.clamp(1, lastDay),
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
  }
}
