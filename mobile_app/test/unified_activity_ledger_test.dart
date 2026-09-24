import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/activity/domain/unified_activity_ledger.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';

void main() {
  test('unified ledger categorises, orders and filters shared records', () {
    final savings = _record(
      id: 'savings',
      createdAt: DateTime(2026, 9, 20),
      personal: true,
    );
    final family = _record(
      id: 'family',
      createdAt: DateTime(2026, 9, 22),
      personal: false,
    );
    final ledger = buildUnifiedActivityLedger(
      savingsRecords: [savings],
      familyRecords: [family],
      familyPocketNames: const {'family-pocket': 'Adebayo Family Care'},
    );

    expect(ledger.map((item) => item.record.id), ['family', 'savings']);
    expect(ledger.first.category, ActivityCategory.family);
    expect(ledger.first.subtitle, 'Adebayo Family Care');
    expect(
      filterUnifiedActivityLedger(
        ledger,
        category: ActivityCategory.savings,
      ).single.record.id,
      'savings',
    );
    expect(
      filterUnifiedActivityLedger(
        ledger,
        dateRange: ActivityDateRange.last7Days,
        now: DateTime(2026, 9, 24),
      ).map((item) => item.record.id),
      ['family', 'savings'],
    );
  });
}

ContributionRecord _record({
  required String id,
  required DateTime createdAt,
  required bool personal,
}) => ContributionRecord(
  id: id,
  contributorUserId: 'user',
  personalHealthPocketId: personal ? 'personal-pocket' : null,
  familyPocketId: personal ? null : 'family-pocket',
  amountKobo: 50000,
  currency: 'NGN',
  status: ContributionStatus.recorded,
  origin: ContributionOrigin.devSimulation,
  moneyMovement: false,
  idempotencyKey: id,
  createdAt: createdAt,
);
