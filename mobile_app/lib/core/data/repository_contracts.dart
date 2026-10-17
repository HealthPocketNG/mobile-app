import 'dart:typed_data';

import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/auth/domain/app_pin.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/funding/domain/funding_transaction.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/wallet/domain/wallet_account.dart';

/// Feature code depends on these contracts, never directly on Firebase or a
/// future payment, KYC, banking, or investment provider.
abstract interface class AuthRepository {
  AuthUser? get currentUser;
  String? get currentUserId;
  Stream<AuthUser?> watchUser();
  Future<AuthUser?> restoreSession();
  Future<bool> hasActiveSession();
  Future<AuthResult?> signInWithGoogle();
  Future<bool> reauthenticateWithGoogle();
  Future<void> signOut();
}

abstract interface class AppPinRepository {
  Future<bool> hasPin(String userId);
  Future<void> setPin({required String userId, required String pin});
  Future<PinVerificationResult> verifyPin({
    required String userId,
    required String pin,
  });
  Future<void> clearPin(String userId);
}

abstract interface class ProfileRepository {
  Stream<UserProfileDocumentData?> watchProfile(String userId);
  Future<UserProfileDocumentData?> getProfile(String userId);
  Future<ProfileProvisioningResult> getOrCreateProfile(AuthUser user);
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
    required AccountOnboardingStatus onboardingStatus,
  });
}

abstract interface class ProfilePhotoRepository {
  Future<String> upload({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  });
  Future<String?> getDownloadUrl({
    required String userId,
    required String? storagePath,
  });
  Future<void> delete({required String userId, required String storagePath});
}

class ProfileProvisioningResult {
  const ProfileProvisioningResult({
    required this.data,
    required this.wasCreated,
  });

  final UserProfileDocumentData data;
  final bool wasCreated;
}

class UserProfileDocumentData {
  const UserProfileDocumentData({
    required this.profile,
    required this.notifications,
    required this.kycStatus,
    required this.onboardingStatus,
  });

  final UserProfile profile;
  final NotificationPreferences notifications;
  final KycStatus kycStatus;
  final AccountOnboardingStatus onboardingStatus;
}

abstract interface class SavingsRepository {
  Stream<PersonalHealthPocket?> watchPersonalPocket(String userId);
  Stream<SavingsPlan?> watchPlan(String userId);
  Future<PersonalHealthPocket?> getPersonalPocket(String userId);
  Future<SavingsPlan?> getPlan(String userId);
  Future<void> savePersonalPocket(PersonalHealthPocket pocket);
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    String? fundingSourceId,
  });
}

abstract interface class ContributionRepository {
  Future<List<ContributionRecord>> getPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  });
  Stream<List<ContributionRecord>> watchPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  });
  Stream<List<ContributionRecord>> watchFamilyContributions(
    String familyPocketId,
  );
  Future<List<ContributionRecord>> getFamilyContributions(
    String familyPocketId,
  );

  /// Creates one immutable development record. Reusing its idempotency key is
  /// a successful no-op and must never create a second record.
  Future<void> recordDevelopmentContribution(ContributionRecord contribution);
  Future<void> recordDevelopmentFamilyContribution(
    ContributionRecord contribution,
  );
}

/// Clients can observe authoritative financial data but cannot mutate it.
/// Balance-changing commands belong to trusted backend services only.
abstract interface class WalletRepository {
  Stream<WalletAccount?> watchWallet(String userId);
  Future<WalletAccount?> getWallet(String userId);
  Future<List<LedgerEntry>> getLedgerEntries({
    required String userId,
    int limit = 50,
  });
  Future<List<FinancialOperation>> getFinancialOperations({
    required String userId,
    int limit = 50,
  });
}

/// Funding transactions are server-owned. Flutter may display their progress
/// and receipt metadata but cannot create or finalize them through Firestore.
abstract interface class FundingRepository {
  Stream<List<FundingTransaction>> watchFundingTransactions({
    required String userId,
    int limit = 50,
  });
  Future<FundingTransaction?> getFundingTransaction({
    required String userId,
    required String transactionId,
  });
}

abstract interface class FamilyPocketRepository {
  Future<List<FamilyPocket>> getPocketsForUser(String userId);
  Future<List<FamilyInvitation>> getPendingInvitationsForEmail(String email);
  Stream<FamilyPocket?> watchPocket(String pocketId);
  Stream<List<FamilyMembership>> watchMembers(String pocketId);
  Stream<List<FamilyMembership>> watchMembershipsForUser(String userId);

  /// Creates a pocket and the founding admin membership atomically.
  Future<void> createPocket({
    required FamilyPocket pocket,
    required String createdBy,
    required FamilyMembership adminMembership,
  });

  Future<void> createInvitation(FamilyInvitation invitation);
  Future<void> respondToInvitation({
    required FamilyInvitation invitation,
    required String userId,
    required String userName,
    required bool accept,
  });
  Future<void> cancelInvitation(FamilyInvitation invitation);
  Future<void> markMemberRemoved({
    required String pocketId,
    required String memberId,
    required bool wasBeneficiary,
    int? beneficiarySlot,
  });
}

abstract interface class ActivityRepository {
  Stream<List<ActivityRecord>> watchUserActivity(String userId);
  Stream<List<ActivityRecord>> watchFamilyActivity(String familyPocketId);
}
