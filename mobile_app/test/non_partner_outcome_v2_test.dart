import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/non_partner_verification.dart';
import 'package:healthpocket/features/care/presentation/care_v2_non_partner_outcomes.dart';
import 'package:healthpocket/features/care/presentation/non_partner_payment_screen.dart';

const _provider = CareProvider(
  id: 'demo-pharmacy',
  name: 'Sunrise Pharmacy',
  state: 'Lagos',
  city: 'Ojota',
  type: CareProviderType.pharmacy,
  services: [],
  isPartner: false,
);

class _MerchantResult implements HealthcareMerchantVerificationService {
  const _MerchantResult(this.status);
  final MerchantVerificationStatus status;

  @override
  Future<MerchantVerificationResult> verifyRecipient({
    required String providerId,
    required ResolvedBankAccount recipient,
  }) async =>
      MerchantVerificationResult(status: status, reason: 'Preview result');
}

class _PendingMerchantResult implements HealthcareMerchantVerificationService {
  final completer = Completer<MerchantVerificationResult>();
  @override
  Future<MerchantVerificationResult> verifyRecipient({
    required String providerId,
    required ResolvedBankAccount recipient,
  }) => completer.future;
}

void main() {
  testWidgets(
    'all four non-partner outcomes fit a narrow phone and show preview status',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const titles = {
        CareNonPartnerOutcome.success: 'Payment Successful!',
        CareNonPartnerOutcome.inReview: 'Payment in review',
        CareNonPartnerOutcome.notCompleted: 'Merchant could not be verified',
        CareNonPartnerOutcome.failed: 'Payment failed',
      };
      for (final outcome in CareNonPartnerOutcome.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: CareV2NonPartnerOutcomeScreen(
              provider: _provider,
              amountKobo: 500000,
              outcome: outcome,
              onDone: () {},
              onRetry: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(titles[outcome]!), findsOneWidget);
        expect(
          find.text('UI preview only · No payment was sent'),
          findsOneWidget,
        );
        expect(find.text('HPX7293840'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'ineligible merchant uses not-completed state without claiming a refund',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NonPartnerPaymentScreen(
            provider: _provider,
            merchantService: _MerchantResult(
              MerchantVerificationStatus.ineligible,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0123456789');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay ₦ 5,000'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Merchant could not be verified'), findsOneWidget);
      expect(find.text('Not charged'), findsOneWidget);
      expect(find.text('Funds returned'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slow merchant check reaches in-review preview and ignores late result',
    (tester) async {
      final merchant = _PendingMerchantResult();
      await tester.pumpWidget(
        MaterialApp(
          home: NonPartnerPaymentScreen(
            provider: _provider,
            merchantService: merchant,
          ),
        ),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0123456789');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay ₦ 5,000'));
      await tester.pump();
      expect(find.text('Verifying merchant'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Payment in review'), findsOneWidget);
      merchant.completer.complete(
        const MerchantVerificationResult(
          status: MerchantVerificationStatus.verified,
          reason: 'Late result',
        ),
      );
      await tester.pump();
      expect(find.text('Payment in review'), findsOneWidget);
      expect(
        find.text('UI preview only · No payment was sent'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('debug long press previews alternative payment outcomes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NonPartnerPaymentScreen(provider: _provider)),
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0123456789');
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Pay ₦ 5,000'));
    await tester.pumpAndSettle();
    expect(find.text('Preview payment outcomes'), findsOneWidget);
    await tester.tap(find.text('Payment in review'));
    await tester.pumpAndSettle();
    expect(find.text('Payment in review'), findsOneWidget);
    expect(find.text('UI preview only · No payment was sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
