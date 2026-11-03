import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/presentation/savings_transfer_v2.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';

void main() {
  testWidgets('dashboard Add Money shortcut opens Add Money directly', (
    tester,
  ) async {
    final savings = SavingsStore();
    final profile = ProfileStore();
    addTearDown(savings.dispose);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoute.addMoney.path: (_) =>
              const Scaffold(body: Text('Add Money destination')),
          AppRoute.savings.path: (_) =>
              const Scaffold(body: Text('Savings destination')),
        },
        home: DashboardScreen(savingsStore: savings, profileStore: profile),
      ),
    );
    await tester.ensureVisible(find.text('Add Money').first);
    await tester.tap(find.text('Add Money').first);
    await tester.pumpAndSettle();
    expect(find.text('Add Money destination'), findsOneWidget);
    expect(find.text('Savings destination'), findsNothing);
  });

  testWidgets('dashboard balance arrow opens Savings History directly', (
    tester,
  ) async {
    final savings = SavingsStore();
    final profile = ProfileStore();
    addTearDown(savings.dispose);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoute.savingsHistory.path: (_) =>
              const Scaffold(body: Text('History destination')),
          AppRoute.savings.path: (_) =>
              const Scaffold(body: Text('Savings destination')),
        },
        home: DashboardScreen(savingsStore: savings, profileStore: profile),
      ),
    );
    await tester.tap(find.byKey(const Key('dashboard-savings-history-arrow')));
    await tester.pumpAndSettle();
    expect(find.text('History destination'), findsOneWidget);
    expect(find.text('Savings destination'), findsNothing);
  });

  testWidgets('transfer preview counts down and receiving spinner rotates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SavingsTransferDetailsV2(amountNaira: 1000)),
    );
    expect(find.text('Expires in 29:42'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Expires in 29:39'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: SavingsReceivingV2(amountNaira: 1000)),
    );
    await tester.pump();
    final spinner = find.byKey(const Key('receiving-spinner'));
    final firstTurn = tester.widget<RotationTransition>(spinner).turns.value;
    await tester.pump(const Duration(milliseconds: 275));
    final nextTurn = tester.widget<RotationTransition>(spinner).turns.value;
    expect(nextTurn, greaterThan(firstTurn));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('direct Add Money keeps the development record flow', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    var records = 0;
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoute.savings.path: (_) =>
              const Scaffold(body: Text('Savings destination')),
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SavingsAddMoneyEntryScreen(
                    store: store,
                    designPreview: true,
                    developmentContributionsEnabled: true,
                    onCreateContributionKey: () => 'test-key',
                    onRecordDevelopmentContribution:
                        ({
                          required amountNaira,
                          required idempotencyKey,
                        }) async {
                          records++;
                          expect(amountNaira, 1000);
                          expect(idempotencyKey, 'test-key');
                        },
                  ),
                ),
              ),
              child: const Text('Open Add Money'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Add Money'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(records, 1);
    expect(find.text('Money Added!'), findsOneWidget);
    await tester.ensureVisible(find.text('Back to Savings'));
    await tester.tap(find.text('Back to Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Savings destination'), findsOneWidget);
  });
}
