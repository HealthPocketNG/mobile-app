import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/presentation/profile_screen.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_more_pages.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_final_pages.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

void main() {
  testWidgets(
    'Reset PIN requires password reauthentication and matching six digits',
    (tester) async {
      final auth = InMemoryAuthRepository();
      addTearDown(auth.dispose);
      await auth.createAccountWithEmail(
        name: 'David',
        email: 'david@example.com',
        password: 'valid-password',
      );
      await auth.signInWithEmail(
        email: 'david@example.com',
        password: 'valid-password',
      );
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileResetPinScreen(
            authRepository: auth,
            onSetPin: (pin) async => saved = pin,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'wrong-password');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set a new PIN'), findsNothing);
      expect(saved, isNull);
      await tester.enterText(find.byType(TextField).first, 'valid-password');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set a new PIN'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '123456');
      await tester.enterText(find.byType(TextField).at(1), '123457');
      await tester.tap(find.text('Save PIN'));
      await tester.pump();
      expect(saved, isNull);
      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();
      expect(saved, '123456');
    },
  );

  testWidgets('FAQs search and Terms tabs show their beta content', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileFaqsScreen()));
    expect(find.text('How does HealthPocket work?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'money');
    await tester.pump();
    expect(find.text('How do I add money?'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: ProfileTermsScreen()));
    expect(find.text('1. Using HealthPocket'), findsOneWidget);
    await tester.tap(find.text('Privacy'));
    await tester.pump();
    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.textContaining('reviewed Privacy Policy'), findsOneWidget);
  });

  testWidgets('new Profile pages fit a narrow phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final page in <Widget>[
      const ProfileReferScreen(),
      const ProfileContactSupportScreen(),
      const ProfileFaqsScreen(),
      const ProfileTermsScreen(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Profile overview opens security and personal information on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProfileStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));

      expect(find.text('More'), findsWidgets);
      await tester.tap(find.text('Account & Security'));
      await tester.pumpAndSettle();
      expect(find.text('Login & PIN'), findsOneWidget);
      await tester.tap(find.text('Personal Information'));
      await tester.pumpAndSettle();
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported Profile notification categories cannot change stored preferences',
    (tester) async {
      final store = ProfileStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      final loginSwitch = tester.widget<Switch>(find.byType(Switch).first);
      expect(loginSwitch.onChanged, isNull);
      expect(store.notifications.savingsReminders, isTrue);
      await tester.scrollUntilVisible(find.text('Marketing & offers'), 250);
      expect(find.text('Marketing & offers'), findsOneWidget);
    },
  );

  testWidgets(
    'Payment Methods uses DEV records and About uses the original logo',
    (tester) async {
      final profile = ProfileStore();
      final savings = SavingsStore();
      addTearDown(profile.dispose);
      addTearDown(savings.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            store: profile,
            savingsStore: savings,
            designPreview: true,
          ),
        ),
      );

      await tester.tap(find.text('Payment Methods'));
      await tester.pumpAndSettle();
      expect(find.text('₦0 · Dev record'), findsOneWidget);
      expect(find.text('No bank accounts yet'), findsOneWidget);
      await tester.tap(find.text('Add Bank Account'));
      await tester.pump();
      expect(
        find.textContaining('real payments are connected'),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -220));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About HealthPocket'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1.0.0 (Beta)'), findsOneWidget);
      expect(find.textContaining('Open-source'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/HPLogo/HPLogo.png',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo sheet and Login & PIN open without enabling unavailable actions',
    (tester) async {
      final store = ProfileStore();
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));
      await tester.tap(find.text('View profile ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-change-photo')));
      await tester.pumpAndSettle();
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(find.textContaining('account storage is ready'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account & Security'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login & PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Change PIN'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('profile-fingerprint-switch')),
            )
            .onChanged,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification permission preview fits a narrow phone and changes no permission',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: ProfileNotificationPermissionScreen()),
      );
      expect(find.text('Stay in the loop'), findsOneWidget);
      await tester.tap(find.text('Turn On Notifications'));
      await tester.pump();
      expect(find.textContaining('No permission was changed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
