import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/activity/presentation/activity_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

void main() {
  testWidgets('empty Activity fits a narrow phone and retains navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: ActivityScreen(savingsStore: store)),
    );

    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.text('Start Saving'), findsOneWidget);
    expect(
      tester
          .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
          .currentIndex,
      3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview filters, details, and receipt stay clearly labelled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityScreen(savingsStore: store, designPreview: true),
      ),
    );

    expect(find.text('Lagoon Clinic'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter activity. Long press to search.'));
    await tester.pumpAndSettle();
    expect(find.text('Filter Activity'), findsOneWidget);
    await tester.tap(find.text('Other'));
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(find.text('No matching activity'), findsOneWidget);
    await tester.tap(find.text('Clear Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagoon Clinic'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'UI preview · No payment or contribution was recorded for this sample.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('View Receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Receipt'));
    await tester.pumpAndSettle();
    expect(find.text('UI preview · Not a payment receipt'), findsOneWidget);
    await tester.tap(find.byTooltip('Download receipt'));
    await tester.pump();
    expect(
      find.text('Receipt export is unavailable for a UI preview.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
