import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

/// Feature code depends on these contracts, never directly on Firebase or a
/// future payment, KYC, banking, or investment provider.
abstract interface class AuthRepository {
  String? get currentUserId;
  Stream<String?> watchUserId();
  Future<bool> hasActiveSession();
  Future<void> signOut();
}

abstract interface class ProfileRepository {
  Stream<UserProfileDocumentData?> watchProfile(String userId);
  Future<UserProfileDocumentData?> getProfile(String userId);
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
  });
}

class UserProfileDocumentData {
  const UserProfileDocumentData({
    required this.profile,
    required this.notifications,
    required this.kycStatus,
  });

  final UserProfile profile;
  final NotificationPreferences notifications;
  final KycStatus kycStatus;
}

abstract interface class SavingsRepository {
  Stream<PersonalHealthPocket?> watchPersonalPocket(String userId);
  Stream<SavingsPlan?> watchPlan(String userId);
  Future<void> savePersonalPocket(PersonalHealthPocket pocket);
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    DateTime? nextContributionDate,
    String? fundingSourceId,
  });
}

abstract interface class ContributionRepository {
  Stream<List<ContributionRecord>> watchPersonalContributions(
    String personalHealthPocketId,
  );
  Stream<List<ContributionRecord>> watchFamilyContributions(
    String familyPocketId,
  );

  /// Persists the ledger entry and its activity record atomically.
  Future<void> recordContribution({
    required ContributionRecord contribution,
    required ActivityRecord activity,
  });
}

abstract interface class FamilyPocketRepository {
  Stream<FamilyPocket?> watchPocket(String pocketId);
  Stream<List<FamilyMembership>> watchMembers(String pocketId);
  Stream<List<FamilyMembership>> watchMembershipsForUser(String userId);

  /// Creates a pocket and the founding admin membership atomically.
  Future<void> createPocket({
    required FamilyPocket pocket,
    required String createdBy,
    required FamilyMembership adminMembership,
  });

  Future<void> saveMembership(FamilyMembership membership);
  Future<void> markContributorRemoved({
    required String pocketId,
    required String memberId,
    required DateTime removedAt,
  });
}

abstract interface class ActivityRepository {
  Stream<List<ActivityRecord>> watchUserActivity(String userId);
  Stream<List<ActivityRecord>> watchFamilyActivity(String familyPocketId);
}
