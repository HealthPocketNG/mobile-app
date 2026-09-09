import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthpocket/core/data/firestore/firestore_documents.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<String?> watchUserId() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Future<bool> hasActiveSession() async => _auth.currentUser != null;

  @override
  Future<void> signOut() => _auth.signOut();
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<UserProfileDocument> _profile(String userId) =>
      FirestoreDocumentCollections.users(_firestore).doc(userId);

  @override
  Stream<UserProfileDocumentData?> watchProfile(String userId) =>
      _profile(userId).snapshots().map(_profileData);

  @override
  Future<UserProfileDocumentData?> getProfile(String userId) async =>
      _profileData(await _profile(userId).get());

  @override
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
  }) {
    final document = UserProfileDocument.fromDomain(
      userId: userId,
      profile: profile,
      notifications: notifications,
      updatedAt: DateTime.now(),
    );
    return _profile(userId).set(document, SetOptions(merge: true));
  }

  UserProfileDocumentData? _profileData(
    DocumentSnapshot<UserProfileDocument> snapshot,
  ) {
    final document = snapshot.data();
    if (document == null) return null;
    return UserProfileDocumentData(
      profile: document.profile,
      notifications: document.notifications,
      kycStatus: document.kycStatus,
    );
  }
}

class FirestoreSavingsRepository implements SavingsRepository {
  FirestoreSavingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<PersonalHealthPocket?> watchPersonalPocket(String userId) =>
      FirestoreDocumentCollections.personalPockets(_firestore)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.isEmpty
                ? null
                : snapshot.docs.first.data().pocket,
          );

  @override
  Stream<SavingsPlan?> watchPlan(String userId) =>
      FirestoreDocumentCollections.savingsPlans(_firestore)
          .where('userId', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.isEmpty
                ? null
                : snapshot.docs.first.data().plan,
          );

  @override
  Future<void> savePersonalPocket(PersonalHealthPocket pocket) =>
      FirestoreDocumentCollections.personalPockets(
        _firestore,
      ).doc(pocket.id).set(PersonalHealthPocketDocument(pocket));

  @override
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    DateTime? nextContributionDate,
    String? fundingSourceId,
  }) async {
    final reference = FirestoreDocumentCollections.savingsPlans(
      _firestore,
    ).doc(plan.id);
    final existing = await reference.get();
    final now = DateTime.now();
    final document = SavingsPlanDocument(
      plan: plan,
      userId: userId,
      personalHealthPocketId: personalHealthPocketId,
      nextContributionDate: nextContributionDate,
      fundingSourceId: fundingSourceId,
      createdAt: existing.data()?.createdAt ?? now,
      updatedAt: now,
    );
    await reference.set(document);
  }
}

class FirestoreContributionRepository implements ContributionRepository {
  FirestoreContributionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ContributionRecord>> watchPersonalContributions(
    String personalHealthPocketId,
  ) => FirestoreDocumentCollections.contributions(_firestore)
      .where('personalHealthPocketId', isEqualTo: personalHealthPocketId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((document) => document.data().contribution)
            .toList(growable: false),
      );

  @override
  Stream<List<ContributionRecord>> watchFamilyContributions(
    String familyPocketId,
  ) => FirestoreDocumentCollections.contributions(_firestore)
      .where('familyPocketId', isEqualTo: familyPocketId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((document) => document.data().contribution)
            .toList(growable: false),
      );

  @override
  Future<void> recordContribution({
    required ContributionRecord contribution,
    required ActivityRecord activity,
  }) {
    if (activity.userId != contribution.contributorUserId) {
      throw ArgumentError(
        'Contribution and activity must belong to the same user.',
      );
    }
    final batch = _firestore.batch();
    batch.set(
      FirestoreDocumentCollections.contributions(
        _firestore,
      ).doc(contribution.id),
      ContributionDocument(contribution),
    );
    batch.set(
      FirestoreDocumentCollections.activities(_firestore).doc(activity.id),
      ActivityRecordDocument(activity),
    );
    return batch.commit();
  }
}

class FirestoreFamilyPocketRepository implements FamilyPocketRepository {
  FirestoreFamilyPocketRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<FamilyPocket?> watchPocket(String pocketId) =>
      FirestoreDocumentCollections.familyPockets(
        _firestore,
      ).doc(pocketId).snapshots().map((snapshot) => snapshot.data()?.pocket);

  @override
  Stream<List<FamilyMembership>> watchMembers(String pocketId) =>
      FirestoreDocumentCollections.familyMembers(_firestore, pocketId)
          .where('invitationStatus', whereNotIn: ['removed'])
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((document) => document.data().membership)
                .toList(growable: false),
          );

  @override
  Stream<List<FamilyMembership>> watchMembershipsForUser(String userId) =>
      _firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: userId)
          .where('invitationStatus', isEqualTo: 'accepted')
          .orderBy('joinedAt', descending: true)
          .withConverter<FamilyMembershipDocument>(
            fromFirestore: (snapshot, _) => FamilyMembershipDocument.fromMap(
              snapshot.id,
              snapshot.data()!,
            ),
            toFirestore: (document, _) => document.toMap(),
          )
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((document) => document.data().membership)
                .toList(growable: false),
          );

  @override
  Future<void> createPocket({
    required FamilyPocket pocket,
    required String createdBy,
    required FamilyMembership adminMembership,
  }) {
    if (adminMembership.id != createdBy ||
        adminMembership.userId != createdBy ||
        adminMembership.pocketId != pocket.id ||
        adminMembership.role != FamilyRole.admin ||
        adminMembership.invitationStatus != FamilyInvitationStatus.accepted) {
      throw ArgumentError('The founding membership must be the accepted admin.');
    }
    final now = DateTime.now();
    final batch = _firestore.batch();
    batch.set(
      FirestoreDocumentCollections.familyPockets(_firestore).doc(pocket.id),
      FamilyPocketDocument(
        pocket: pocket,
        createdBy: createdBy,
        currency: 'NGN',
        status: FamilyPocketStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
    );
    batch.set(
      FirestoreDocumentCollections.familyMembers(
        _firestore,
        pocket.id,
      ).doc(adminMembership.id),
      FamilyMembershipDocument(adminMembership),
    );
    return batch.commit();
  }

  @override
  Future<void> saveMembership(FamilyMembership membership) =>
      FirestoreDocumentCollections.familyMembers(
        _firestore,
        membership.pocketId,
      ).doc(membership.id).set(FamilyMembershipDocument(membership));

  @override
  Future<void> markContributorRemoved({
    required String pocketId,
    required String memberId,
    required DateTime removedAt,
  }) => FirestoreDocumentCollections.familyMembers(
    _firestore,
    pocketId,
  ).doc(memberId).update({
    'invitationStatus': FamilyInvitationStatus.removed.name,
    'removedAt': Timestamp.fromDate(removedAt),
  });
}

class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ActivityRecord>> watchUserActivity(String userId) =>
      FirestoreDocumentCollections.activities(_firestore)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(_activities);

  @override
  Stream<List<ActivityRecord>> watchFamilyActivity(String familyPocketId) =>
      FirestoreDocumentCollections.activities(_firestore)
          .where('familyPocketId', isEqualTo: familyPocketId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(_activities);

  List<ActivityRecord> _activities(
    QuerySnapshot<ActivityRecordDocument> snapshot,
  ) => snapshot.docs
      .map((document) => document.data().activity)
      .toList(growable: false);
}

class FirebaseRepositoryBundle {
  FirebaseRepositoryBundle({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : auth = FirebaseAuthRepository(auth),
       profiles = FirestoreProfileRepository(firestore),
       savings = FirestoreSavingsRepository(firestore),
       contributions = FirestoreContributionRepository(firestore),
       familyPockets = FirestoreFamilyPocketRepository(firestore),
       activities = FirestoreActivityRepository(firestore);

  final AuthRepository auth;
  final ProfileRepository profiles;
  final SavingsRepository savings;
  final ContributionRepository contributions;
  final FamilyPocketRepository familyPockets;
  final ActivityRepository activities;
}
