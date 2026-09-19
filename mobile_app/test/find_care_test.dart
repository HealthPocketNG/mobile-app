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
    expect(
      providers.every((p) => p.isDemo && p.phone == null && p.address == null),
      isTrue,
    );
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
  testWidgets('search, empty state, clear and demo details', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('No providers match'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No providers match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Community');
    await tester.pump();
    await tester.ensureVisible(find.text('Demo Community Clinic'));
    await tester.tap(find.text('Demo Community Clinic'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No booking, payment'), findsOneWidget);
    expect(find.text('Pay Demo Community Clinic — demo authorization'),
        findsNothing);
  });
  testWidgets('location states and provider-first action render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FindCareScreen(demoRequestsEnabled: true)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Location has not been requested'), findsOneWidget);
    await tester.tap(find.text('Use mock location'));
    await tester.pump();
    expect(find.textContaining('Demo location enabled'), findsOneWidget);
    expect(find.textContaining('2.4 km'), findsOneWidget);
    await tester.tap(find.text('Simulate denied'));
    await tester.pump();
    expect(find.textContaining('permission denied'), findsOneWidget);
    await tester.tap(find.text('Simulate unavailable'));
    await tester.pump();
    expect(find.textContaining('Location is unavailable'), findsOneWidget);
    await tester.tap(find.text('Demo Community Clinic'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Demo Community Clinic — demo authorization'),
        findsOneWidget);
  });
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
    expect(find.text('4 providers'), findsOneWidget);
  });
  testWidgets('empty directory explains that no partners are available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FindCareScreen(repository: _EmptyDirectory())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('No demo partner centres'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No demo partner centres'), findsOneWidget);
  });
}
