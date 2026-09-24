import 'package:healthpocket/features/contributions/domain/contribution_record.dart';

enum ActivityCategory { all, savings, payments, family, other }

enum ActivityDateRange { allTime, last7Days, last30Days, custom }

class ActivityDateInterval {
  const ActivityDateInterval({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

class ActivityLedgerItem {
  const ActivityLedgerItem({
    required this.record,
    required this.category,
    required this.title,
    required this.subtitle,
  });

  final ContributionRecord record;
  final ActivityCategory category;
  final String title;
  final String subtitle;

  bool get isIncoming => record.amountKobo > 0;
}

List<ActivityLedgerItem> buildUnifiedActivityLedger({
  required Iterable<ContributionRecord> savingsRecords,
  required Iterable<ContributionRecord> familyRecords,
  Map<String, String> familyPocketNames = const {},
}) {
  final items =
      <ActivityLedgerItem>[
        ...savingsRecords.map(
          (record) => ActivityLedgerItem(
            record: record,
            category: ActivityCategory.savings,
            title: 'Savings Contribution',
            subtitle: record.note ?? 'Personal HealthPocket',
          ),
        ),
        ...familyRecords.map((record) {
          final pocketName = familyPocketNames[record.familyPocketId];
          return ActivityLedgerItem(
            record: record,
            category: ActivityCategory.family,
            title: 'Family Pocket Contribution',
            subtitle: pocketName ?? record.contributorName ?? 'Family Pocket',
          );
        }),
      ]..sort((first, second) {
        final firstDate = first.record.createdAt;
        final secondDate = second.record.createdAt;
        if (firstDate == null && secondDate == null) return 0;
        if (firstDate == null) return 1;
        if (secondDate == null) return -1;
        return secondDate.compareTo(firstDate);
      });
  return List.unmodifiable(items);
}

List<ActivityLedgerItem> filterUnifiedActivityLedger(
  Iterable<ActivityLedgerItem> items, {
  ActivityCategory category = ActivityCategory.all,
  ActivityDateRange dateRange = ActivityDateRange.allTime,
  DateTime? now,
  ActivityDateInterval? customRange,
}) {
  final today = now ?? DateTime.now();
  final start = switch (dateRange) {
    ActivityDateRange.allTime => null,
    ActivityDateRange.last7Days => today.subtract(const Duration(days: 7)),
    ActivityDateRange.last30Days => today.subtract(const Duration(days: 30)),
    ActivityDateRange.custom => customRange?.start,
  };
  final end = dateRange == ActivityDateRange.custom ? customRange?.end : null;
  return items
      .where((item) {
        if (category != ActivityCategory.all && item.category != category) {
          return false;
        }
        final createdAt = item.record.createdAt;
        if (start != null && (createdAt == null || createdAt.isBefore(start))) {
          return false;
        }
        return end == null || (createdAt != null && !createdAt.isAfter(end));
      })
      .toList(growable: false);
}
