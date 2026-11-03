import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';
import 'package:healthpocket/features/savings/presentation/savings_v2_screens.dart';

void main() {
  testWidgets('V2 plan editor saves through the existing callback', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SavingsScreen(
          store: store,
          onSavePlan:
              ({
                required contributionAmountKobo,
                required frequency,
                required startDate,
              }) async {
                saves++;
                store.configurePlan(
                  contributionAmountKobo: contributionAmountKobo,
                  frequency: frequency,
                  startDate: startDate,
                );
              },
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.enterText(find.byType(TextField), '750');
    await tester.tap(find.text('Save Plan'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(store.plan?.contributionAmountKobo, 75000);
    expect(store.plan?.frequency, SavingsFrequency.monthly);
    expect(find.text('Monthly Savings'), findsOneWidget);
  });

  testWidgets('custom keypad enforces funding limits and returns amount', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => selected = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavingsCustomAmountV2(),
                ),
              ),
              child: const Text('Open keypad'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open keypad'));
    await tester.pumpAndSettle();
    for (final digit in ['1', '0', '0']) {
      await tester.tap(find.text(digit));
    }
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.text('Enter an amount from ₦500 to ₦1,000,000.'),
      findsOneWidget,
    );
    expect(selected, isNull);
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const Key('savings-keypad-delete')));
    }
    for (final digit in ['7', '5', '0', '0']) {
      await tester.tap(find.text(digit));
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(selected, 7500);
  });

  testWidgets('plan card keeps date and pause actions available', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: SavingsScreen(store: store)));
    await tester.tap(find.text('Weekly Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Change start date'), findsOneWidget);
    expect(find.text('Pause plan'), findsOneWidget);
    await tester.tap(find.text('Change start date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly Savings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause plan'));
    await tester.pumpAndSettle();
    expect(store.plan?.status, SavingsPlanStatus.paused);
  });

  testWidgets('Savings V2 pages fit a 320px phone', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: SavingsScreen(store: store)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Money'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: SavingsMoneyAddedV2(
          amountNaira: 2000,
          newBalanceKobo: 1450000,
          onBack: _noop,
          onActivity: _noop,
          developmentRecord: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Money Added!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
