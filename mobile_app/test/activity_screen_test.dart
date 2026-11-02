import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/activity/presentation/activity_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

void main() {
  testWidgets('activity renders unified-ledger filters and empty state', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ActivityScreen(savingsStore: store)),
    );

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Savings'), findsWidgets);
    expect(find.text('Family'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search activity'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(find.text('No activity yet'), findsOneWidget);
  });
}
