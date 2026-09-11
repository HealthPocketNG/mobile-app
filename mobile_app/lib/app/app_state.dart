import 'package:flutter/foundation.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/domain/app_pin.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

/// Owns only application-wide UI state. Feature state belongs to its feature.
class AppState extends ChangeNotifier {
  AppState({
    AuthRepository? authRepository,
    AppPinRepository? pinRepository,
    this.profileRepository,
    this.savingsRepository,
  }) : authRepository = authRepository ?? InMemoryAuthRepository(),
       pinRepository =
           pinRepository ??
           SecureAppPinRepository(storage: MemorySecureValueStore());

  final AuthRepository authRepository;
  final AppPinRepository pinRepository;
  final ProfileRepository? profileRepository;
  final SavingsRepository? savingsRepository;
  final FamilyPocketStore familyPocketStore = FamilyPocketStore();
  final ProfileStore profileStore = ProfileStore();
  final SavingsStore savingsStore = SavingsStore();
  bool _hasCompletedOnboarding = false;
  bool _pendingNewAccount = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  Future<AuthFlowDestination> resolveStartup() async {
    final user = authRepository.currentUser;
    if (user == null) return AuthFlowDestination.welcome;
    if (!user.emailVerified) return AuthFlowDestination.verifyEmail;
    return _destinationForVerifiedUser(user);
  }

  Future<AuthFlowDestination> acceptAuthentication(AuthResult result) async {
    _pendingNewAccount = result.isNewUser;
    if (result.isNewUser) {
      _beginRegistrationFor(result.user);
    }
    if (!result.user.emailVerified) {
      return AuthFlowDestination.verifyEmail;
    }
    if (result.isNewUser) return AuthFlowDestination.personalInformation;
    return _destinationForVerifiedUser(result.user);
  }

  Future<AuthFlowDestination> acceptEmailVerification() async {
    final user = await authRepository.reloadCurrentUser();
    if (user == null || !user.emailVerified) {
      return AuthFlowDestination.verifyEmail;
    }
    if (_pendingNewAccount) {
      profileStore.verifyEmailAddress();
      return AuthFlowDestination.personalInformation;
    }
    return _destinationForVerifiedUser(user);
  }

  Future<void> setPin(String pin) async {
    final userId = authRepository.currentUserId;
    if (userId == null) throw const AuthFailure('Your session has expired.');
    await pinRepository.setPin(userId: userId, pin: pin);
    _pendingNewAccount = false;
  }

  Future<PinVerificationResult> verifyPin(String pin) async {
    final userId = authRepository.currentUserId;
    if (userId == null) throw const AuthFailure('Your session has expired.');
    return pinRepository.verifyPin(userId: userId, pin: pin);
  }

  Future<void> resetPinAfterReauthentication() async {
    final userId = authRepository.currentUserId;
    if (userId == null) throw const AuthFailure('Your session has expired.');
    await pinRepository.clearPin(userId);
  }

  Future<void> signOut() async {
    _pendingNewAccount = false;
    await authRepository.signOut();
  }

  Future<AuthFlowDestination> _destinationForVerifiedUser(AuthUser user) async {
    final profiles = profileRepository;
    final savings = savingsRepository;
    if (profiles != null && savings != null) {
      final profileData = await profiles.getProfile(user.uid);
      final pocket = await savings.getPersonalPocket(user.uid);
      final plan = await savings.getPlan(user.uid);

      if (profileData == null || pocket == null || plan == null) {
        _pendingNewAccount = true;
        if (profileData == null) {
          profileStore.beginRegistration(
            fullName: user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'HealthPocket User',
            email: user.email ?? '',
            phoneNumber: '',
            emailVerified: user.emailVerified,
          );
        } else {
          profileStore.hydrate(
            profile: profileData.profile,
            notifications: profileData.notifications,
          );
        }
        savingsStore.hydrate(plan: plan);
        familyPocketStore.resetForNewUser(
          name: profileStore.profile.fullName,
          email: profileStore.profile.email,
        );
        _hasCompletedOnboarding = false;
        return AuthFlowDestination.personalInformation;
      }

      profileStore.hydrate(
        profile: profileData.profile,
        notifications: profileData.notifications,
      );
      savingsStore.hydrate(plan: plan);
      familyPocketStore.resetForNewUser(
        name: profileData.profile.fullName,
        email: profileData.profile.email,
      );
      _hasCompletedOnboarding = true;
    } else if (profiles != null &&
        await profiles.getProfile(user.uid) == null) {
      _pendingNewAccount = true;
      _beginRegistrationFor(user);
      return AuthFlowDestination.personalInformation;
    }

    return await pinRepository.hasPin(user.uid)
        ? AuthFlowDestination.unlockPin
        : AuthFlowDestination.createPin;
  }

  void _beginRegistrationFor(AuthUser user) {
    profileStore.beginRegistration(
      fullName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'HealthPocket User',
      email: user.email ?? '',
      phoneNumber: '',
      emailVerified: user.emailVerified,
    );
    beginRegistration();
  }

  void beginRegistration() {
    _hasCompletedOnboarding = false;
    savingsStore.resetForOnboarding();
    familyPocketStore.resetForNewUser(
      name: profileStore.profile.fullName,
      email: profileStore.profile.email,
    );
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final user = authRepository.currentUser;
    if (user == null || !user.emailVerified) {
      throw const AuthFailure(
        'Sign in with a verified account before completing setup.',
      );
    }
    final currentPlan = savingsStore.plan;
    if (currentPlan == null) {
      throw StateError('Create a savings plan before completing setup.');
    }

    final now = DateTime.now();
    final profile = profileStore.profile.copyWith(
      email: user.email ?? profileStore.profile.email,
      emailVerified: true,
      phoneVerified: false,
      demoKycComplete: false,
    );
    final pocket = PersonalHealthPocket(
      id: 'personal-${user.uid}',
      userId: user.uid,
      currency: 'NGN',
      status: PersonalHealthPocketStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    final plan = SavingsPlan(
      id: 'personal-plan-${user.uid}',
      contributionAmount: currentPlan.contributionAmount,
      frequency: currentPlan.frequency,
      startDate: currentPlan.startDate,
      status: currentPlan.status,
    );

    profileStore.hydrate(
      profile: profile,
      notifications: profileStore.notifications,
    );
    savingsStore.hydrate(plan: plan);

    final profiles = profileRepository;
    final savings = savingsRepository;
    if (profiles != null && savings != null) {
      // Deterministic IDs make each step safe to retry if connectivity fails.
      await profiles.saveProfile(
        userId: user.uid,
        profile: profile,
        notifications: profileStore.notifications,
      );
      await savings.savePersonalPocket(pocket);
      await savings.savePlan(
        userId: user.uid,
        personalHealthPocketId: pocket.id,
        plan: plan,
      );
    }

    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  Future<void> updateSavingsPlan({
    required int contributionAmount,
    required SavingsFrequency frequency,
    required DateTime startDate,
  }) async {
    final currentPlan = savingsStore.plan;
    if (currentPlan == null) {
      throw StateError('No savings plan is available to update.');
    }
    await _persistSavingsPlan(
      currentPlan.copyWith(
        contributionAmount: contributionAmount,
        frequency: frequency,
        startDate: startDate,
      ),
    );
  }

  Future<void> toggleSavingsPlan() async {
    final currentPlan = savingsStore.plan;
    if (currentPlan == null) {
      throw StateError('No savings plan is available to update.');
    }
    await _persistSavingsPlan(
      currentPlan.copyWith(
        status: currentPlan.status == SavingsPlanStatus.paused
            ? SavingsPlanStatus.active
            : SavingsPlanStatus.paused,
      ),
    );
  }

  Future<void> _persistSavingsPlan(SavingsPlan plan) async {
    final savings = savingsRepository;
    if (savings != null) {
      final userId = authRepository.currentUserId;
      if (userId == null) {
        throw const AuthFailure('Your session has expired.');
      }
      await savings.savePlan(
        userId: userId,
        personalHealthPocketId: 'personal-$userId',
        plan: plan,
      );
    }
    savingsStore.replacePlan(plan);
  }

  @override
  void dispose() {
    familyPocketStore.dispose();
    profileStore.dispose();
    savingsStore.dispose();
    super.dispose();
  }
}

enum AuthFlowDestination {
  welcome,
  verifyEmail,
  personalInformation,
  createPin,
  unlockPin,
}
