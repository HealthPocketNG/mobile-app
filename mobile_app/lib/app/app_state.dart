import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/domain/app_pin.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
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
    this.contributionRepository,
    this.familyPocketRepository,
    this.developmentContributionsEnabled = false,
  }) : authRepository = authRepository ?? InMemoryAuthRepository(),
       pinRepository =
           pinRepository ??
           SecureAppPinRepository(storage: MemorySecureValueStore());

  final AuthRepository authRepository;
  final AppPinRepository pinRepository;
  final ProfileRepository? profileRepository;
  final SavingsRepository? savingsRepository;
  final ContributionRepository? contributionRepository;
  final FamilyPocketRepository? familyPocketRepository;
  final bool developmentContributionsEnabled;
  final FamilyPocketStore familyPocketStore = FamilyPocketStore();
  final ProfileStore profileStore = ProfileStore();
  final SavingsStore savingsStore = SavingsStore();
  bool _hasCompletedOnboarding = false;
  bool _pendingNewAccount = false;
  String? _personalHealthPocketId;

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
    _personalHealthPocketId = null;
    savingsStore.clearContributionState();
    familyPocketStore.resetForNewUser(name: '', email: '');
    await authRepository.signOut();
  }

  Future<AuthFlowDestination> _destinationForVerifiedUser(AuthUser user) async {
    // Clear account-scoped records before any asynchronous restore work so a
    // previous account can never remain visible during an account switch.
    _personalHealthPocketId = null;
    savingsStore.clearContributionState();
    final profiles = profileRepository;
    final savings = savingsRepository;
    if (profiles != null && savings != null) {
      final profileData = await profiles.getProfile(user.uid);
      final pocket = await savings.getPersonalPocket(user.uid);
      final plan = await savings.getPlan(user.uid);

      if (profileData == null) {
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
        if (plan != null) savingsStore.hydrate(plan: plan);
        _startFamilyPocketRestore(
          userId: user.uid,
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
      if (plan != null) savingsStore.hydrate(plan: plan);
      if (pocket != null) {
        _personalHealthPocketId = pocket.id;
        _watchPersonalContributions(userId: user.uid, pocketId: pocket.id);
      }
      _startFamilyPocketRestore(
        userId: user.uid,
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
    _personalHealthPocketId = null;
    savingsStore.resetForOnboarding();
    familyPocketStore.resetForNewUser(
      userId: authRepository.currentUserId ?? 'current-user',
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
    _personalHealthPocketId = pocket.id;

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

    _watchPersonalContributions(userId: user.uid, pocketId: pocket.id);
    _startFamilyPocketRestore(
      userId: user.uid,
      name: profile.fullName,
      email: profile.email,
    );

    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  /// Completes the beta profile step without creating a savings plan.
  /// Savings plans are intentionally created from the Savings feature.
  Future<void> completeProfileOnboarding() async {
    final user = authRepository.currentUser;
    if (user == null || !user.emailVerified) {
      throw const AuthFailure(
        'Sign in with a verified account before completing setup.',
      );
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
    profileStore.hydrate(
      profile: profile,
      notifications: profileStore.notifications,
    );
    _personalHealthPocketId = pocket.id;
    final profiles = profileRepository;
    final savings = savingsRepository;
    if (profiles != null) {
      await profiles.saveProfile(
        userId: user.uid,
        profile: profile,
        notifications: profileStore.notifications,
      );
    }
    if (savings != null) await savings.savePersonalPocket(pocket);
    _startFamilyPocketRestore(
      userId: user.uid,
      name: profile.fullName,
      email: profile.email,
    );
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

  Future<void> updateAccountDetails(UserProfile draft) async {
    final userId = authRepository.currentUserId;
    if (userId == null) throw const AuthFailure('Your session has expired.');
    if (draft.fullName.trim().isEmpty ||
        draft.stateOfResidence.trim().isEmpty) {
      throw const AuthFailure('Name and state of residence are required.');
    }
    final previous = profileStore.profile;
    final updated = previous.copyWith(
      fullName: draft.fullName.trim(),
      phoneNumber: draft.phoneNumber.trim(),
      stateOfResidence: draft.stateOfResidence.trim(),
      phoneVerified:
          previous.phoneNumber == draft.phoneNumber.trim() &&
          previous.phoneVerified,
    );
    await profileRepository?.saveProfile(
      userId: userId,
      profile: updated,
      notifications: profileStore.notifications,
    );
    if (authRepository.currentUserId != userId) {
      throw const AuthFailure('Your account changed while saving.');
    }
    profileStore.hydrate(
      profile: updated,
      notifications: profileStore.notifications,
    );
  }

  Future<void> updatePersonalDetails(
    UserProfile draft,
    bool emergencyContact,
  ) async {
    final userId = authRepository.currentUserId;
    if (userId == null) throw const AuthFailure('Your session has expired.');
    if (emergencyContact) {
      if (draft.nextOfKinName.trim().isEmpty ||
          !RegExp(r'^\+?[0-9 ()-]{7,25}$')
              .hasMatch(draft.nextOfKinPhone.trim())) {
        throw const AuthFailure('Enter a contact name and valid phone number.');
      }
    } else {
      final now = DateTime.now();
      final birth = draft.dateOfBirth;
      if (birth == null ||
          birth.isAfter(DateTime(now.year - 18, now.month, now.day)) ||
          birth.isBefore(DateTime(now.year - 100)) ||
          draft.gender == null ||
          draft.residentialAddress.trim().isEmpty ||
          draft.stateOfResidence.trim().isEmpty) {
        throw const AuthFailure('Complete your personal information.');
      }
    }
    final current = profileStore.profile;
    final updated = emergencyContact
        ? current.copyWith(
            nextOfKinName: draft.nextOfKinName.trim(),
            nextOfKinPhone: draft.nextOfKinPhone.trim(),
          )
        : current.copyWith(
            dateOfBirth: draft.dateOfBirth,
            gender: draft.gender,
            residentialAddress: draft.residentialAddress.trim(),
            stateOfResidence: draft.stateOfResidence.trim(),
          );
    await profileRepository?.saveProfile(
      userId: userId,
      profile: updated,
      notifications: profileStore.notifications,
    );
    if (authRepository.currentUserId != userId) {
      throw const AuthFailure('Your account changed while saving.');
    }
    profileStore.hydrate(
      profile: updated,
      notifications: profileStore.notifications,
    );
  }

  Future<void> updateNotificationPreferences(
    NotificationPreferences notifications,
  ) async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw const AuthFailure('Your session has expired.');
    }
    final repository = profileRepository;
    if (repository != null) {
      await repository.saveProfile(
        userId: userId,
        profile: profileStore.profile,
        notifications: notifications,
      );
    }
    if (authRepository.currentUserId != userId) {
      throw const AuthFailure('Your account changed while saving.');
    }
    profileStore.replaceNotifications(notifications);
  }

  Future<void> refreshDashboard() async {
    final userId = authRepository.currentUserId;
    final profiles = profileRepository;
    final savings = savingsRepository;
    if (userId == null) {
      throw const AuthFailure('Your session has expired.');
    }
    if (profiles == null || savings == null) {
      return;
    }

    final dashboardData = await Future.wait<Object?>([
      profiles.getProfile(userId),
      savings.getPersonalPocket(userId),
      savings.getPlan(userId),
    ]);
    final profileData = dashboardData[0] as UserProfileDocumentData?;
    final pocket = dashboardData[1] as PersonalHealthPocket?;
    final plan = dashboardData[2] as SavingsPlan?;
    if (profileData == null || pocket == null || plan == null) {
      throw StateError('Your saved dashboard setup is incomplete.');
    }

    List<ContributionRecord>? contributions;
    final contributionData = contributionRepository;
    if (developmentContributionsEnabled && contributionData != null) {
      contributions = await contributionData.getPersonalContributions(
        userId: userId,
        personalHealthPocketId: pocket.id,
      );
    }
    if (authRepository.currentUserId != userId) {
      throw const AuthFailure('Your account changed while refreshing.');
    }

    profileStore.hydrate(
      profile: profileData.profile,
      notifications: profileData.notifications,
    );
    savingsStore.replacePlan(plan);
    if (_personalHealthPocketId != pocket.id) {
      _personalHealthPocketId = pocket.id;
      _watchPersonalContributions(userId: userId, pocketId: pocket.id);
    }
    if (contributions != null) {
      savingsStore.replacePersonalContributions(
        userId: userId,
        personalHealthPocketId: pocket.id,
        records: contributions,
      );
    }
  }

  Future<void> refreshFamilyPockets() async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw const AuthFailure('Your session has expired.');
    }
    await _loadFamilyPockets(userId);
  }

  Future<void> createFamilyPocket({required String name}) async {
    final userId = _requireUserId();
    final repository = familyPocketRepository;
    if (repository == null) {
      familyPocketStore.createPocket(name: name);
      return;
    }
    final now = DateTime.now();
    final pocketId = 'family_${userId}_${createDevelopmentContributionKey()}';
    await repository.createPocket(
      pocket: FamilyPocket(id: pocketId, name: name.trim(), members: const []),
      createdBy: userId,
      adminMembership: FamilyMembership(
        id: userId,
        pocketId: pocketId,
        userId: userId,
        name: profileStore.profile.fullName,
        role: FamilyRole.admin,
        canContribute: true,
        isBeneficiary: false,
        status: FamilyMembershipStatus.accepted,
        joinedAt: now,
      ),
    );
    await _loadFamilyPockets(userId);
  }

  Future<void> inviteFamilyMember({
    required String name,
    required String email,
    required bool canContribute,
    required bool isBeneficiary,
  }) async {
    final userId = _requireUserId();
    final pocket = familyPocketStore.selectedPocket;
    final repository = familyPocketRepository;
    if (pocket == null || !familyPocketStore.canManageMembers) {
      throw StateError('Only a Family Pocket admin can record invitations.');
    }
    if (repository == null) {
      final invited = familyPocketStore.inviteMember(
        name: name,
        email: email,
        canContribute: canContribute,
        isBeneficiary: isBeneficiary,
      );
      if (!invited) {
        throw StateError('This invitation cannot be created.');
      }
      return;
    }
    await repository.createInvitation(
      FamilyInvitation(
        id: 'invite_${userId}_${createDevelopmentContributionKey()}',
        pocketId: pocket.id,
        pocketName: pocket.name,
        inviteeName: name.trim(),
        email: email.trim().toLowerCase(),
        inviterName: profileStore.profile.fullName,
        canContribute: canContribute,
        isBeneficiary: isBeneficiary,
        status: FamilyInvitationStatus.pending,
        createdBy: userId,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    );
    await _loadFamilyPockets(userId);
  }

  Future<void> respondToFamilyInvitation(
    FamilyInvitation invitation, {
    required bool accept,
  }) async {
    final userId = _requireUserId();
    final repository = familyPocketRepository;
    if (repository == null) {
      if (!familyPocketStore.respondToInvitation(
        invitation.id,
        accept: accept,
      )) {
        throw StateError('This invitation is no longer pending.');
      }
      return;
    }
    await repository.respondToInvitation(
      invitation: invitation,
      userId: userId,
      userName: profileStore.profile.fullName,
      accept: accept,
    );
    await _loadFamilyPockets(userId);
  }

  Future<void> cancelFamilyInvitation(FamilyInvitation invitation) async {
    final userId = _requireUserId();
    final repository = familyPocketRepository;
    if (repository == null) {
      if (!familyPocketStore.cancelInvitation(invitation.id)) {
        throw StateError('This invitation is no longer pending.');
      }
      return;
    }
    await repository.cancelInvitation(invitation);
    await _loadFamilyPockets(userId);
  }

  Future<void> removeFamilyMember(String memberId) async {
    final userId = _requireUserId();
    final pocket = familyPocketStore.selectedPocket;
    final repository = familyPocketRepository;
    if (pocket == null || !familyPocketStore.canManageMembers) {
      throw StateError('Only a Family Pocket admin can remove contributors.');
    }
    if (repository == null) {
      if (!familyPocketStore.removeMember(memberId)) {
        throw StateError('This member cannot be removed.');
      }
      return;
    }
    final member = pocket.members
        .where((item) => item.id == memberId)
        .firstOrNull;
    if (member == null) throw StateError('This member no longer exists.');
    await repository.markMemberRemoved(
      pocketId: pocket.id,
      memberId: memberId,
      wasBeneficiary: member.isBeneficiary,
      beneficiarySlot: member.beneficiarySlot,
    );
    await _loadFamilyPockets(userId);
  }

  Future<void> recordDevelopmentFamilyContribution({
    required int amountNaira,
    required String idempotencyKey,
  }) async {
    if (!developmentContributionsEnabled) {
      throw StateError(
        'Simulated Family Pocket records are unavailable in this build.',
      );
    }
    if (amountNaira <= 0 || amountNaira > 1000000000) {
      throw ArgumentError.value(amountNaira, 'amountNaira');
    }
    final userId = _requireUserId();
    final pocket = familyPocketStore.selectedPocket;
    final repository = contributionRepository;
    if (pocket == null || repository == null) {
      throw StateError(
        'Your Family Pocket is not ready. Refresh and try again.',
      );
    }
    await repository.recordDevelopmentFamilyContribution(
      ContributionRecord(
        id: 'dev_family_${userId}_$idempotencyKey',
        contributorUserId: userId,
        familyPocketId: pocket.id,
        contributorName: profileStore.profile.fullName,
        amountKobo: amountNaira * 100,
        currency: 'NGN',
        status: ContributionStatus.recorded,
        origin: ContributionOrigin.devSimulation,
        moneyMovement: false,
        idempotencyKey: idempotencyKey,
        createdAt: null,
      ),
    );
    await _loadFamilyPockets(userId);
  }

  String _requireUserId() {
    final userId = authRepository.currentUserId;
    if (userId == null) throw const AuthFailure('Your session has expired.');
    return userId;
  }

  void _startFamilyPocketRestore({
    required String userId,
    required String name,
    required String email,
  }) {
    familyPocketStore.resetForNewUser(userId: userId, name: name, email: email);
    if (familyPocketRepository == null) return;
    unawaited(
      _loadFamilyPockets(userId).catchError((Object _) {
        // The store already exposes the recoverable failure state.
      }),
    );
  }

  Future<void> _loadFamilyPockets(String userId) async {
    final familyRepository = familyPocketRepository;
    if (familyRepository == null) return;
    familyPocketStore.beginLoad();
    try {
      final authUser = authRepository.currentUser;
      final email = authUser?.email?.trim().toLowerCase() ?? '';
      final results = await Future.wait<Object>([
        familyRepository.getPocketsForUser(userId),
        if (authUser?.emailVerified == true && email.isNotEmpty)
          familyRepository.getPendingInvitationsForEmail(email)
        else
          Future<List<FamilyInvitation>>.value(const []),
      ]);
      final pockets = results[0] as List<FamilyPocket>;
      final receivedInvitations = results[1] as List<FamilyInvitation>;
      final contributions =
          developmentContributionsEnabled && contributionRepository != null
          ? (await Future.wait(
              pockets.map(
                (pocket) =>
                    contributionRepository!.getFamilyContributions(pocket.id),
              ),
            )).expand((records) => records).toList(growable: false)
          : <ContributionRecord>[];
      if (authRepository.currentUserId != userId) {
        throw const AuthFailure('Your account changed while refreshing.');
      }
      familyPocketStore.hydratePersistent(
        userId: userId,
        name: profileStore.profile.fullName,
        email: profileStore.profile.email,
        pockets: pockets,
        contributions: contributions,
        receivedInvitations: receivedInvitations,
      );
    } catch (error) {
      if (authRepository.currentUserId == userId) {
        familyPocketStore.setLoadFailure(error);
      }
      rethrow;
    }
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

  String createDevelopmentContributionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> recordDevelopmentContribution({
    required int amountNaira,
    required String idempotencyKey,
  }) async {
    if (!developmentContributionsEnabled) {
      throw StateError(
        'Simulated contribution records are unavailable in this build.',
      );
    }
    if (amountNaira <= 0 || amountNaira > 1000000000) {
      throw ArgumentError.value(
        amountNaira,
        'amountNaira',
        'Enter an amount from ₦1 to ₦1,000,000,000.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(idempotencyKey)) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        'Use a 16–80 character contribution request key.',
      );
    }
    final userId = authRepository.currentUserId;
    final pocketId = _personalHealthPocketId;
    final plan = savingsStore.plan;
    final repository = contributionRepository;
    if (userId == null ||
        pocketId == null ||
        plan == null ||
        repository == null) {
      throw StateError(
        'Your savings setup is not ready. Refresh and try again.',
      );
    }

    await repository.recordDevelopmentContribution(
      ContributionRecord(
        id: 'dev_${userId}_$idempotencyKey',
        contributorUserId: userId,
        personalHealthPocketId: pocketId,
        savingsPlanId: plan.id,
        amountKobo: amountNaira * 100,
        currency: 'NGN',
        status: ContributionStatus.recorded,
        origin: ContributionOrigin.devSimulation,
        moneyMovement: false,
        idempotencyKey: idempotencyKey,
        createdAt: null,
      ),
    );
  }

  void retryContributionLoad() => savingsStore.retryContributionLoad();

  void _watchPersonalContributions({
    required String userId,
    required String pocketId,
  }) {
    final repository = contributionRepository;
    if (!developmentContributionsEnabled || repository == null) return;
    savingsStore.watchPersonalContributions(
      userId: userId,
      personalHealthPocketId: pocketId,
      streamFactory: () => repository.watchPersonalContributions(
        userId: userId,
        personalHealthPocketId: pocketId,
      ),
    );
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
