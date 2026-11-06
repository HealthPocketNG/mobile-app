import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/find_care_screen.dart';

class _FailOnce implements CareDirectoryRepository {
  bool failed = false;
  @override
  Future<List<CareProvider>> getProviders() async {
    if (!failed) {
      failed = true;
      throw StateError('Offline');
    }
    return const DemoCareDirectoryRepository().getProviders();
  }
}

class _EmptyDirectory implements CareDirectoryRepository {
  @override
  Future<List<CareProvider>> getProviders() async => const [];
}

void main() {
  test('directory combines name, state and type filters', () async {
    final providers = await const DemoCareDirectoryRepository().getProviders();
    expect(providers.every((p) => p.isDemo && p.phone == null), isTrue);
    expect(
      filterCareProviders(
        providers,
        query: '  PHARMACY ',
        state: 'Lagos',
        type: CareProviderType.pharmacy,
      ).length,
      1,
    );
    expect(
      filterCareProviders(
        providers,
        state: 'Rivers',
        type: CareProviderType.pharmacy,
      ),
      isEmpty,
    );
  });
  testWidgets('focused search finds providers and opens demo details', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search for clinics, pharmacies...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mala');
    await tester.pump();
    expect(find.text('malaria treatment'), findsOneWidget);
    expect(find.text('malaria test'), findsOneWidget);
    expect(find.text('Demo Community Clinic'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('No providers match'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Community');
    await tester.pump();
    await tester.ensureVisible(find.text('Demo Community Clinic'));
    await tester.tap(find.text('Demo Community Clinic'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No booking, payment'), findsOneWidget);
    expect(
      find.text('Pay Demo Community Clinic — demo authorization'),
      findsNothing,
    );
  });
  testWidgets(
    'location chooser, permission view and no-results actions render',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FindCareScreen(demoRequestsEnabled: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Change location'), findsOneWidget);
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(find.text('Find care near you'), findsOneWidget);
      await tester.tap(find.text('Allow Location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not enabled in this build'), findsOneWidget);
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter Location Manually'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abraka'));
      await tester.pumpAndSettle();
      expect(find.text('No partners nearby'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('View all providers'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all providers'));
      await tester.pumpAndSettle();
      expect(find.text('HealthPocket Partners'), findsOneWidget);
    },
  );
  testWidgets('failed load can be retried', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FindCareScreen(repository: _FailOnce())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Retry'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('HealthPocket Partners'), findsOneWidget);
  });
  testWidgets('empty directory explains that no partners are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FindCareScreen(repository: _EmptyDirectory())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No partners nearby'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No partners nearby'), findsOneWidget);
  });

  testWidgets('filters sheet applies provider type and can reset', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Provider type'), findsOneWidget);
    await tester.tap(find.text('Clinics').last);
    await tester.ensureVisible(find.text('Show Results'));
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Community Clinic'), findsOneWidget);
    expect(find.text('Demo Neighbourhood Pharmacy'), findsNothing);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.ensureVisible(find.text('Show Results'));
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Neighbourhood Pharmacy'), findsOneWidget);
  });

  testWidgets('partner status filter separates partner and non-partner care', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Other Healthcare Providers'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('See all').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Demo Health Hospital'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Demo Health Hospital'), findsOneWidget);
    expect(find.text('Demo Community Clinic'), findsNothing);
  });
}
