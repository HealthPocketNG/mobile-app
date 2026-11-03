import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/dashboard/domain/coverage_guide.dart';
import 'package:healthpocket/features/dashboard/presentation/coverage_details_screen.dart';

void main() {
  testWidgets('V2 coverage list filters and opens both balance states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoverageDetailsScreen(balanceKobo: 1250000, designPreview: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Covers 4 of 6'), findsOneWidget);
    expect(find.text('Covered by your balance'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Almost there'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Almost there'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Malaria treatment'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Malaria treatment'));
    await tester.pumpAndSettle();
    expect(find.text('What\'s usually included'), findsOneWidget);
    expect(find.text('Lagoon Clinic'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(CoverBack),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Eyes'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Eyes'));
    await tester.pumpAndSettle();
    expect(find.text('Malaria treatment'), findsNothing);
    expect(find.text('Spectacles (basic)'), findsOneWidget);
    await tester.tap(find.text('Spectacles (basic)'));
    await tester.pumpAndSettle();
    expect(find.text('₦7,500 to go'), findsOneWidget);
    expect(find.text('Ways to get there'), findsOneWidget);
    expect(find.text('Set a Savings Plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'coverage screens fit 320px width and retain savings navigation',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoute.savings.path: (_) =>
                const Scaffold(body: Text('Savings destination')),
          },
          home: const CoverageDetailsScreen(balanceKobo: 1250000),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Spectacles (basic)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Spectacles (basic)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Add Money'));
      await tester.pumpAndSettle();
      expect(find.text('Savings destination'), findsOneWidget);
    },
  );

  testWidgets('covered detail fits a narrow phone', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: CoverageItemScreen(
            guide: coverageCatalog.first,
            balanceKobo: 1250000,
            designPreview: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find Care'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
