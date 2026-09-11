import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/app/health_pocket_app.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/presentation/profile_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';

void main() {
  testWidgets('shows the HealthPocket launch screen', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    expect(find.byType(AppBrandLogo), findsOneWidget);
  });

  testWidgets('moves from launch to account creation', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prepare for medical'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('explains that Google sign-up also requires consent', (
    tester,
  ) async {
    await tester.pumpWidget(const HealthPocketApp());
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Accept the Terms and Privacy Policy to sign up with Google.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard shows savings summary and core navigation', (
    tester,
  ) async {
    final store = SavingsStore();
    final profileStore = ProfileStore();
    addTearDown(store.dispose);
    addTearDown(profileStore.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(savingsStore: store, profileStore: profileStore),
      ),
    );

    expect(find.text('Health savings balance'), findsOneWidget);
    expect(find.text('₦42,300'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Family Pocket'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('records a mock savings contribution', (tester) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: SavingsScreen(store: store)));

    await tester.tap(find.text('Add savings').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '5000');
    await tester.tap(find.text('Record mock contribution'));
    await tester.pumpAndSettle();

    expect(find.text('₦47,300'), findsOneWidget);
    expect(store.contributions.first.amount, 5000);
  });

  testWidgets('opens a restored savings plan for editing', (tester) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: SavingsScreen(store: store)));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit savings plan'));
    await tester.pumpAndSettle();

    expect(find.text('Edit savings plan'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<SavingsFrequency>>(
            find.byType(DropdownButtonFormField<SavingsFrequency>),
          )
          .initialValue,
      SavingsFrequency.weekly,
    );
  });

  testWidgets('invites a Family Pocket member', (tester) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Tola Adebayo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'tola@example.com',
    );
    await tester.tap(find.text('Send demo invite'));
    await tester.pumpAndSettle();

    expect(find.text('Tola Adebayo'), findsOneWidget);
    expect(store.selectedPocket!.members.last.isPending, isTrue);
  });

  testWidgets('allows an admin to remove a Family Pocket contributor', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    final contributionCount = store.selectedContributions.length;
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );

    final removeButton = find.byKey(const ValueKey('remove-member-grace'));
    await tester.scrollUntilVisible(
      removeButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(removeButton),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove contributor'));
    await tester.pumpAndSettle();

    expect(
      store.selectedPocket!.members.any((member) => member.id == 'grace'),
      isFalse,
    );
    expect(store.selectedContributions, hasLength(contributionCount));
    expect(
      store.selectedContributions.any((item) => item.memberName == 'Grace'),
      isTrue,
    );
  });

  testWidgets('updates a profile notification preference', (tester) async {
    final store = ProfileStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));

    expect(store.notifications.savingsReminders, isTrue);
    final preferenceFinder = find.byKey(
      const ValueKey('savings-reminders-switch'),
    );
    await tester.scrollUntilVisible(
      preferenceFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    var preference = tester.widget<SwitchListTile>(preferenceFinder);
    expect(preference.value, isTrue);

    preference.onChanged!(false);
    await tester.pump();

    expect(store.notifications.savingsReminders, isFalse);
    preference = tester.widget<SwitchListTile>(preferenceFinder);
    expect(preference.value, isFalse);
  });

  test('connects MVP onboarding data to the shared app stores', () async {
    final appState = AppState();
    addTearDown(appState.dispose);

    await appState.authRepository.signInWithEmail(
      email: 'amara@example.com',
      password: 'secure-password',
    );

    appState.profileStore.beginRegistration(
      fullName: 'Amara Okafor',
      email: 'amara@example.com',
      phoneNumber: '+234 801 234 5678',
    );
    appState.beginRegistration();
    appState.profileStore.updatePersonalInformation(
      dateOfBirth: DateTime(1995, 4, 18),
      gender: 'female',
      residentialAddress: '21 Market Road',
      stateOfResidence: 'Rivers',
      nextOfKinName: 'Chidi Okafor',
      nextOfKinPhone: '+234 809 876 5432',
    );
    appState.savingsStore.saveOnboardingPlan(
      contributionAmount: 2500,
      frequency: SavingsFrequency.monthly,
      startDate: DateTime(2026, 10, 1),
    );
    appState.savingsStore.saveOnboardingPlan(
      contributionAmount: 3000,
      frequency: SavingsFrequency.weekly,
      startDate: DateTime(2026, 10, 8),
    );
    await appState.completeOnboarding();

    final profile = appState.profileStore.profile;
    expect(profile.fullName, 'Amara Okafor');
    expect(profile.stateOfResidence, 'Rivers');
    expect(profile.nextOfKinName, 'Chidi Okafor');
    expect(profile.phoneVerified, isFalse);
    expect(profile.demoKycComplete, isFalse);
    expect(appState.savingsStore.plan!.contributionAmount, 3000);
    expect(appState.savingsStore.plan!.frequency, SavingsFrequency.weekly);
    expect(appState.savingsStore.plan!.startDate, DateTime(2026, 10, 8));
    expect(appState.savingsStore.currentBalance, 0);
    expect(appState.hasCompletedOnboarding, isTrue);
  });
}
