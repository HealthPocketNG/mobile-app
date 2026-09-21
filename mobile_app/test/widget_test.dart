import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/app/health_pocket_app.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/presentation/profile_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

    expect(find.text('Total Savings'), findsOneWidget);
    expect(find.text('₦0'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Family Pocket'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
  });

  testWidgets('pulling down refreshes dashboard data', (tester) async {
    final store = SavingsStore();
    final profileStore = ProfileStore();
    var refreshCount = 0;
    addTearDown(store.dispose);
    addTearDown(profileStore.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          savingsStore: store,
          profileStore: profileStore,
          onRefresh: () async => refreshCount++,
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(refreshCount, 1);
  });

  testWidgets('records a clearly labelled development contribution', (
    tester,
  ) async {
    final store = SavingsStore();
    final records = StreamController<List<ContributionRecord>>();
    addTearDown(store.dispose);
    addTearDown(records.close);
    store.watchPersonalContributions(
      userId: 'demo-user',
      personalHealthPocketId: 'personal-demo-user',
      streamFactory: () => records.stream,
    );
    records.add(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: SavingsScreen(
          store: store,
          developmentContributionsEnabled: true,
          onCreateContributionKey: () => '0123456789abcdef',
          onRecordDevelopmentContribution:
              ({
                required int amountNaira,
                required String idempotencyKey,
              }) async {
                records.add([
                  ContributionRecord(
                    id: 'dev_demo-user_$idempotencyKey',
                    contributorUserId: 'demo-user',
                    personalHealthPocketId: 'personal-demo-user',
                    savingsPlanId: 'personal-savings-plan',
                    amountKobo: amountNaira * 100,
                    currency: 'NGN',
                    status: ContributionStatus.recorded,
                    origin: ContributionOrigin.devSimulation,
                    moneyMovement: false,
                    idempotencyKey: idempotencyKey,
                    createdAt: DateTime(2026, 9, 11),
                  ),
                ]);
              },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add development record'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '5000');
    await tester.tap(find.text('Record development contribution'));
    await tester.pumpAndSettle();

    expect(find.text('₦5,000'), findsWidgets);
    expect(store.contributions.first.amountKobo, 500000);
    expect(find.textContaining('no money moved'), findsWidgets);
  });

  testWidgets('opens a restored savings plan for editing', (tester) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: SavingsScreen(store: store)));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit savings plan'));
    await tester.pumpAndSettle();

    expect(find.text('Set Your Savings Plan'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('₦5,000'), findsWidgets);
    expect(find.byIcon(LucideIcons.circleDot), findsOneWidget);
  });

  testWidgets('production UI exposes no simulated contribution action', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: SavingsScreen(store: store)));

    expect(find.text('Add development record'), findsNothing);
    expect(find.text('Record development contribution'), findsNothing);
  });

  testWidgets('dashboard activity uses the ordered contribution records', (
    tester,
  ) async {
    final store = SavingsStore();
    final profileStore = ProfileStore();
    final records = StreamController<List<ContributionRecord>>();
    addTearDown(store.dispose);
    addTearDown(profileStore.dispose);
    addTearDown(records.close);
    store.watchPersonalContributions(
      userId: 'demo-user',
      personalHealthPocketId: 'personal-demo-user',
      streamFactory: () => records.stream,
    );
    records.add([
      _developmentRecord(
        key: 'aaaaaaaaaaaaaaaa',
        amountKobo: 100000,
        createdAt: DateTime(2026, 9, 9),
      ),
      _developmentRecord(
        key: 'bbbbbbbbbbbbbbbb',
        amountKobo: 200000,
        createdAt: DateTime(2026, 9, 10),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          savingsStore: store,
          profileStore: profileStore,
          developmentContributionsEnabled: true,
        ),
      ),
    );
    await tester.pump();
    expect(store.contributions.first.amountKobo, 200000);
    expect(store.developmentBalanceKobo, 300000);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('+₦2,000'), findsOneWidget);
    expect(find.text('+₦1,000'), findsOneWidget);
    expect(find.textContaining('No money moved'), findsWidgets);
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
    await tester.tap(find.text('Record invitation'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tola Adebayo'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tola Adebayo'), findsOneWidget);
    expect(
      store.selectedPocket!.invitations.last.effectiveStatus,
      FamilyInvitationStatus.pending,
    );
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
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();

    expect(
      store.selectedPocket!.members.any((member) => member.id == 'grace'),
      isFalse,
    );
    expect(store.selectedContributions, hasLength(contributionCount));
    expect(
      store.selectedContributions.any(
        (item) => item.contributorName == 'Grace',
      ),
      isTrue,
    );
  });

  testWidgets('production Family Pocket exposes no simulated contribution', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyPocketScreen(
          store: store,
          developmentContributionsEnabled: false,
        ),
      ),
    );

    expect(find.text('Dev record'), findsNothing);
    expect(find.text('Shared funding is not enabled'), findsOneWidget);
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
    expect(appState.savingsStore.developmentBalanceKobo, 0);
    expect(appState.hasCompletedOnboarding, isTrue);
  });
}

ContributionRecord _developmentRecord({
  required String key,
  required int amountKobo,
  required DateTime createdAt,
}) => ContributionRecord(
  id: 'dev_demo-user_$key',
  contributorUserId: 'demo-user',
  personalHealthPocketId: 'personal-demo-user',
  savingsPlanId: 'personal-savings-plan',
  amountKobo: amountKobo,
  currency: 'NGN',
  status: ContributionStatus.recorded,
  origin: ContributionOrigin.devSimulation,
  moneyMovement: false,
  idempotencyKey: key,
  createdAt: createdAt,
);
