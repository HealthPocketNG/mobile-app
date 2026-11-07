import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/care/presentation/find_care_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

void main() {
  testWidgets('partner explanation opens from Find Care and closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('What is a HealthPocket Partner?'));
    await tester.pumpAndSettle();
    expect(find.text('Verified by us'), findsOneWidget);
    expect(find.text('Faster payments'), findsOneWidget);
    expect(find.text('Easy to find'), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Verified by us'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Find Care V2 reaches insufficient balance without moving money',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final savings = SavingsStore();
      addTearDown(savings.dispose);
      final initialBalance = savings.developmentBalanceKobo;
      await tester.pumpWidget(
        MaterialApp(home: FindCareScreen(savingsStore: savings)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Healthcare, near you.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Demo Community Clinic'));
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Pay Demo Community Clinic'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Pay Demo Community Clinic'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Amount'), findsOneWidget);
      expect(find.text('₦ 5,000'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Bank Transfer'), findsOneWidget);
      expect(find.text('Demo bank'), findsOneWidget);
      expect(find.text('0000000000'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Review Payment'), findsOneWidget);
      expect(find.text('Pay ₦ 5,000'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Pay ₦ 5,000'));
      await tester.pumpAndSettle();
      expect(find.text('Insufficient Balance'), findsOneWidget);
      expect(find.text('Add Money'), findsOneWidget);
      expect(find.text('Choose a Different Amount'), findsOneWidget);
      expect(savings.developmentBalanceKobo, initialBalance);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'funded demo preview reaches PIN, processing and result without a payment',
    (tester) async {
      final savings = SavingsStore();
      addTearDown(savings.dispose);
      savings.watchPersonalContributions(
        userId: 'preview-user',
        personalHealthPocketId: 'preview-pocket',
        streamFactory: () => Stream.value([
          ContributionRecord(
            id: 'preview-contribution',
            contributorUserId: 'preview-user',
            personalHealthPocketId: 'preview-pocket',
            amountKobo: 500000,
            currency: 'NGN',
            status: ContributionStatus.recorded,
            origin: ContributionOrigin.devSimulation,
            moneyMovement: false,
            idempotencyKey: 'preview-contribution',
            createdAt: DateTime(2026, 1, 1),
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(home: FindCareScreen(savingsStore: savings)),
      );
      await tester.pumpAndSettle();
      final originalBalance = savings.developmentBalanceKobo;
      expect(originalBalance, 500000);
      await tester.tap(find.text('Demo Community Clinic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay Demo Community Clinic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay ₦ 5,000'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm payment'), findsOneWidget);
      expect(find.textContaining('4-digit demo PIN'), findsOneWidget);
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      expect(find.text('Sending your payment...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Payment\nSuccessful!'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(savings.developmentBalanceKobo, originalBalance);
      expect(find.textContaining('QR'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('non-partner details retain the existing verification path', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Demo Health Hospital'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Demo Health Hospital'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay with HealthPocket'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Amount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-partner bank selection and account error use V2 states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: FindCareScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Demo Health Hospital'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Demo Health Hospital'));
    await tester.pumpAndSettle();
    final nonPartnerNote = find.textContaining(
      'This provider is not yet',
      findRichText: true,
    );
    await tester.scrollUntilVisible(
      nonPartnerNote,
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(nonPartnerNote);
    await tester.pumpAndSettle();
    await tester.tap(nonPartnerNote);
    await tester.pumpAndSettle();
    expect(find.text("Paying a provider that isn't a partner"), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay with HealthPocket'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Amount'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Bank Transfer'), findsOneWidget);
    await tester.tap(find.text('Access Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Select Bank'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kuda');
    await tester.pump();
    await tester.tap(find.text('Kuda').last);
    await tester.pumpAndSettle();
    expect(find.text('Kuda'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0123456780');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text("We couldn't find this account. Check the number and bank."),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '0123456789');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Review Payment'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Learn more ›'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Learn more ›'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn more ›'));
    await tester.pumpAndSettle();
    expect(find.text('How merchant verification works'), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Pay ₦ 5,000'), findsOneWidget);
    await tester.tap(find.text('Pay ₦ 5,000'));
    await tester.pump();
    expect(find.text('Verifying merchant'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Sending your payment...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Payment Successful!'), findsOneWidget);
    expect(find.text('UI preview only · No payment was sent'), findsOneWidget);
    expect(find.text('View Receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
