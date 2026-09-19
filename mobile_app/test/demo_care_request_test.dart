import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/domain/demo_care_request.dart';
import 'package:healthpocket/features/care/presentation/demo_care_journey_screen.dart';

void main() {
  test('amount accepts positive naira and rejects unsafe values', () {
    expect(parseCareAmount('18.50'), 1850);
    expect(parseCareAmount('1000000'), 100000000);
    for (final value in ['', '0', '-1', '1e3', 'NaN', '1.001', '1000000.01']) {
      expect(parseCareAmount(value), isNull);
    }
  });

  test('QR resolves only stable HealthPocket provider IDs', () {
    expect(parseDemoProviderQr('hp://provider/demo_clinic_001'),
        'demo_clinic_001');
    for (final raw in [
      'https://example.com',
      'hp://provider/demo_clinic_001?amount=1',
      'hp://provider/Demo Clinic',
      '',
    ]) {
      expect(parseDemoProviderQr(raw), isNull);
    }
  });

  test('matching, mismatch, unknown, inactive and repeat resolution are safe',
      () async {
    final providers = await const DemoCareDirectoryRepository().getProviders();
    DemoAuthorizationSession session(String id) => DemoAuthorizationSession(
          providers: providers,
          selectedProviderId: id,
          amountKobo: 1850000,
        );
    final matching = session('demo_clinic_001');
    final result = matching.resolve('hp://provider/demo_clinic_001');
    expect(result.status, DemoAuthorizationStatus.created);
    expect(result.reference, startsWith('DEMO-'));
    expect(identical(result, matching.resolve('hp://provider/demo_clinic_001')),
        isTrue);

    expect(session('demo_clinic_001').resolve('hp://provider/demo_pharmacy_001').message,
        contains('mismatch'));
    expect(session('demo_clinic_001').resolve('invalid').status,
        DemoAuthorizationStatus.rejected);
    expect(session('demo_clinic_001').resolve('hp://provider/wrong_partner_999').message,
        contains('not found'));
    expect(session('demo_clinic_002').resolve('hp://provider/demo_clinic_002').message,
        contains('inactive'));
  });

  testWidgets('selected provider and amount are confirmed before demo result',
      (tester) async {
    final providers = await const DemoCareDirectoryRepository().getProviders();
    await tester.pumpWidget(MaterialApp(
      home: DemoCareJourneyScreen(
        providers: providers,
        selectedProviderId: 'demo_clinic_001',
      ),
    ));
    await tester.enterText(find.byType(TextField), '18500');
    await tester.tap(find.text('Confirm amount and continue to scan'));
    await tester.pump();
    expect(find.text('Amount: ₦18500.00'), findsOneWidget);
    expect(find.text('Demo Community Clinic'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'hp://provider/demo_clinic_001',
    );
    await tester.ensureVisible(find.text('Resolve demo QR'));
    await tester.tap(find.text('Resolve demo QR'));
    await tester.pumpAndSettle();
    expect(find.text('Demo authorization created'), findsOneWidget);
    expect(find.textContaining('No payment was processed'), findsOneWidget);
  });
}
