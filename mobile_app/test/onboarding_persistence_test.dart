import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

void main() {
  test(
    'persists onboarding and restores it without seeded mock state',
    () async {
      final auth = InMemoryAuthRepository();
      final profiles = _MemoryProfileRepository();
      final savings = _MemorySavingsRepository();
      final secureValues = MemorySecureValueStore();
      final appState = AppState(
        authRepository: auth,
        pinRepository: SecureAppPinRepository(storage: secureValues),
        profileRepository: profiles,
        savingsRepository: savings,
      );

      final result = await auth.createAccountWithEmail(
        fullName: 'Amara Okafor',
        email: 'amara@example.com',
        password: 'secure-password',
      );
      expect(
        await appState.acceptAuthentication(result),
        AuthFlowDestination.verifyEmail,
      );
      auth.markEmailVerified();
      expect(
        await appState.acceptEmailVerification(),
        AuthFlowDestination.personalInformation,
      );

      appState.profileStore.updatePersonalInformation(
        dateOfBirth: DateTime(1995, 4, 18),
        gender: 'female',
        residentialAddress: '21 Market Road',
        stateOfResidence: 'Rivers',
        nextOfKinName: 'Chidi Okafor',
        nextOfKinPhone: '+2348098765432',
      );
      appState.savingsStore.saveOnboardingPlan(
        contributionAmount: 3000,
        frequency: SavingsFrequency.weekly,
        startDate: DateTime(2026, 10, 8),
      );

      await appState.completeOnboarding();

      expect(profiles.data?.profile.fullName, 'Amara Okafor');
      expect(profiles.data?.profile.stateOfResidence, 'Rivers');
      expect(profiles.data?.profile.emailVerified, isTrue);
      expect(profiles.data?.profile.phoneVerified, isFalse);
      expect(savings.pocket?.id, 'personal-demo-user');
      expect(savings.plan?.id, 'personal-plan-demo-user');
      expect(savings.plan?.contributionAmount, 3000);

      await appState.updateSavingsPlan(
        contributionAmount: 4500,
        frequency: SavingsFrequency.daily,
        startDate: DateTime(2026, 10, 12),
      );
      expect(savings.plan?.contributionAmount, 4500);
      expect(savings.plan?.frequency, SavingsFrequency.daily);

      await appState.toggleSavingsPlan();
      expect(savings.plan?.status, SavingsPlanStatus.paused);

      await appState.setPin('482913');
      appState.dispose();

      final restoredState = AppState(
        authRepository: auth,
        pinRepository: SecureAppPinRepository(storage: secureValues),
        profileRepository: profiles,
        savingsRepository: savings,
      );
      addTearDown(restoredState.dispose);
      addTearDown(auth.dispose);

      expect(
        await restoredState.resolveStartup(),
        AuthFlowDestination.unlockPin,
      );
      expect(restoredState.profileStore.profile.fullName, 'Amara Okafor');
      expect(
        restoredState.savingsStore.plan?.frequency,
        SavingsFrequency.daily,
      );
      expect(restoredState.savingsStore.developmentBalanceKobo, 0);
      expect(restoredState.familyPocketStore.pockets, isEmpty);
    },
  );

  test('does not complete onboarding when persistence fails', () async {
    final auth = InMemoryAuthRepository();
    final profiles = _MemoryProfileRepository();
    final savings = _MemorySavingsRepository()..failPlanSave = true;
    final appState = AppState(
      authRepository: auth,
      pinRepository: SecureAppPinRepository(storage: MemorySecureValueStore()),
      profileRepository: profiles,
      savingsRepository: savings,
    );
    addTearDown(appState.dispose);
    addTearDown(auth.dispose);

    await auth.signInWithEmail(
      email: 'amara@example.com',
      password: 'secure-password',
    );
    appState.profileStore.beginRegistration(
      fullName: 'Amara Okafor',
      email: 'amara@example.com',
      phoneNumber: '',
      emailVerified: true,
    );
    appState.savingsStore.saveOnboardingPlan(
      contributionAmount: 5000,
      frequency: SavingsFrequency.monthly,
      startDate: DateTime(2026, 10, 1),
    );

    await expectLater(appState.completeOnboarding(), throwsStateError);
    expect(appState.hasCompletedOnboarding, isFalse);

    savings.failPlanSave = false;
    await appState.completeOnboarding();
    expect(appState.hasCompletedOnboarding, isTrue);
  });

  test('persists notification preferences and restores them', () async {
    final auth = InMemoryAuthRepository();
    final profiles = _MemoryProfileRepository();
    final savings = _MemorySavingsRepository();
    final appState = AppState(
      authRepository: auth,
      profileRepository: profiles,
      savingsRepository: savings,
    );
    addTearDown(appState.dispose);
    addTearDown(auth.dispose);

    final result = await auth.signInWithEmail(
      email: 'amara@example.com',
      password: 'secure-password',
    );
    await appState.acceptAuthentication(result);
    appState.profileStore.beginRegistration(
      fullName: 'Amara Okafor',
      email: 'amara@example.com',
      phoneNumber: '',
      emailVerified: true,
    );
    appState.savingsStore.saveOnboardingPlan(
      contributionAmount: 5000,
      frequency: SavingsFrequency.weekly,
      startDate: DateTime(2026, 10, 1),
    );
    await appState.completeOnboarding();

    final updated = appState.profileStore.notifications.copyWith(
      savingsReminders: false,
    );
    await appState.updateNotificationPreferences(updated);

    expect(profiles.data?.notifications.savingsReminders, isFalse);
    expect(appState.profileStore.notifications.savingsReminders, isFalse);

    profiles.failSave = true;
    await expectLater(
      appState.updateNotificationPreferences(
        updated.copyWith(savingsReminders: true),
      ),
      throwsStateError,
    );
    expect(appState.profileStore.notifications.savingsReminders, isFalse);
  });
}

class _MemoryProfileRepository implements ProfileRepository {
  UserProfileDocumentData? data;
  bool failSave = false;

  @override
  Future<UserProfileDocumentData?> getProfile(String userId) async => data;

  @override
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
  }) async {
    if (failSave) throw StateError('simulated profile write failure');
    data = UserProfileDocumentData(
      profile: profile,
      notifications: notifications,
      kycStatus: KycStatus.notStarted,
    );
  }

  @override
  Stream<UserProfileDocumentData?> watchProfile(String userId) =>
      Stream.value(data);
}

class _MemorySavingsRepository implements SavingsRepository {
  PersonalHealthPocket? pocket;
  SavingsPlan? plan;
  bool failPlanSave = false;

  @override
  Future<PersonalHealthPocket?> getPersonalPocket(String userId) async =>
      pocket;

  @override
  Future<SavingsPlan?> getPlan(String userId) async => plan;

  @override
  Future<void> savePersonalPocket(PersonalHealthPocket value) async {
    pocket = value;
  }

  @override
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    DateTime? nextContributionDate,
    String? fundingSourceId,
  }) async {
    if (failPlanSave) throw StateError('simulated write failure');
    this.plan = plan;
  }

  @override
  Stream<PersonalHealthPocket?> watchPersonalPocket(String userId) =>
      Stream.value(pocket);

  @override
  Stream<SavingsPlan?> watchPlan(String userId) => Stream.value(plan);
}
