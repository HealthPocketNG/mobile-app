import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/care/domain/demo_care_request.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/presentation/demo_care_journey_screen.dart';
import 'package:healthpocket/features/care/presentation/find_care_screen.dart';

void main() {
  test('QR is strictly a demo identifier, not a URL or authorization', () {
    expect(
      parseDemoProviderQr('healthpocket-demo:provider:demo-clinic'),
      'demo-clinic',
    );
    for (final raw in [
      'https://example.com',
      'healthpocket-demo:provider:demo-clinic?amount=1',
      '',
      'healthpocket-demo:provider:demo-clinic\n',
    ]) {
      expect(parseDemoProviderQr(raw), isNull);
    }
  });
  test('amount parsing uses integer kobo and enforces limits', () {
    expect(parseCareAmount('18.50'), 1850);
    expect(parseCareAmount('0.01'), 1);
    expect(parseCareAmount('1000000'), 100000000);
    for (final value in ['0', '-1', '1e3', 'NaN', '1.001', '1000000.01']) {
      expect(parseCareAmount(value), isNull);
    }
  });
  test('lifecycle rejects stale transitions and terminal changes', () {
    final request = DemoCareRequest(
      id: 'test',
      providerName: 'Demo',
      amountKobo: 100,
    );
    request.advance(CareRequestStatus.requested);
    expect(
      () => request.advance(CareRequestStatus.requested),
      throwsStateError,
    );
    expect(request.cancel, throwsStateError);
    while (request.status != CareRequestStatus.settled) {
      request.advance(request.status);
    }
    expect(request.events.length, 6);
    expect(() => request.advance(CareRequestStatus.settled), throwsStateError);
    final cancelled = DemoCareRequest(
      id: 'cancel',
      providerName: 'Demo',
      amountKobo: 100,
    );
    cancelled.cancel();
    expect(
      () => cancelled.advance(CareRequestStatus.cancelled),
      throwsStateError,
    );
  });
  testWidgets('manual QR review creates a request and operator advances it', (
    tester,
  ) async {
    final providers = await const DemoCareDirectoryRepository().getProviders();
    await tester.pumpWidget(
      MaterialApp(home: DemoCareJourneyScreen(providers: providers)),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'healthpocket-demo:provider:demo-clinic',
    );
    await tester.tap(find.text('Check code'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '18500');
    await tester.ensureVisible(find.text('Review request'));
    await tester.tap(find.text('Review request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create simulation'));
    await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open DEV operator simulator'));
      await tester.pumpAndSettle();
    await tester.tap(find.text('Open DEV operator simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate: Authorized'));
    await tester.pump();
    expect(find.text('SIMULATED Authorized'), findsOneWidget);
  });
  testWidgets('simulator entry is hidden by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Try demo care request'), findsNothing);
  });
}
