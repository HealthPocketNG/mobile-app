import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/presentation/savings_history_v2.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';
import 'package:healthpocket/features/savings/presentation/savings_v2_screens.dart';

void main() {
  testWidgets('Savings history filters the Figma preview records', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SavingsHistoryV2(store: store, designPreview: true)),
    );
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Savings Contribution'), findsAtLeastNWidgets(3));
    await tester.tap(find.text('Plan Savings'));
    await tester.pump();
    expect(find.text('Savings Contribution'), findsAtLeastNWidgets(3));
    expect(find.text('+ ₦2,000'), findsNothing);
    expect(find.text('August 2026'), findsOneWidget);
    await tester.tap(find.text('Failed'));
    await tester.pump();
    expect(find.text('No failed entries yet.'), findsOneWidget);
  });

  testWidgets('actual development records replace preview history', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    store.watchPersonalContributions(
      userId: 'user-1',
      personalHealthPocketId: 'pocket-1',
      streamFactory: () => Stream.value([
        ContributionRecord(
          id: 'entry-1',
          contributorUserId: 'user-1',
          personalHealthPocketId: 'pocket-1',
          amountKobo: 75000,
          currency: 'NGN',
          status: ContributionStatus.recorded,
          origin: ContributionOrigin.devSimulation,
          moneyMovement: false,
          idempotencyKey: 'key-1',
          createdAt: DateTime(2026, 10, 2, 9),
        ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(home: SavingsHistoryV2(store: store, designPreview: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsNothing);
    expect(find.text('+ ₦750'), findsOneWidget);
    await tester.tap(find.text('Plan Savings'));
    await tester.pump();
    expect(find.text('No plan entries yet.'), findsOneWidget);
  });

  testWidgets('bank transfer preview runs through receiving and retry states', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SavingsScreen(store: store, designPreview: true)),
    );
    await tester.tap(find.text('Add Money'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay with Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Transfer to Add Money'), findsOneWidget);
    expect(find.text('Demo Bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("I've sent the money"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Confirming your transfer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text("We haven't received your transfer"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Check Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Confirming your transfer'), findsOneWidget);
  });

  testWidgets('live Add Money does not expose a demo bank account', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SavingsAddMoneyV2(canRecordDevelopmentContribution: false),
      ),
    );
    await tester.tap(find.text('Pay with Bank'));
    await tester.pump();
    expect(find.text('Bank transfers are not available yet.'), findsOneWidget);
    expect(find.text('Demo Bank'), findsNothing);
  });
}
