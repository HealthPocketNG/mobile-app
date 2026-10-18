import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:healthpocket/core/data/backend_ids.dart';
import 'package:healthpocket/core/data/firestore/firestore_documents.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/core/logging/backend_logger.dart';
import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/funding/domain/funding_transaction.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/domain/savings_schedule.dart';
import 'package:healthpocket/features/wallet/domain/wallet_account.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository._(this._auth, this._googleSignIn);

  static Future<FirebaseAuthRepository> initialize(FirebaseAuth auth) async {
    final googleSignIn = GoogleSignIn.instance;
    if (!kIsWeb) await googleSignIn.initialize();
    return FirebaseAuthRepository._(auth, googleSignIn);
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  AuthUser? get currentUser => _mapGoogleUser(_auth.currentUser);

  @override
  String? get currentUserId => currentUser?.uid;

  @override
  Stream<AuthUser?> watchUser() => _auth.userChanges().map(_mapGoogleUser);

  @override
  Future<bool> hasActiveSession() async => currentUser != null;

  @override
  Future<AuthUser?> restoreSession() async {
    final existing = _auth.currentUser;
    if (existing == null) return null;
    try {
      await existing.reload();
      final restored = _mapGoogleUser(_auth.currentUser);
      if (restored == null) await _signOutSafely();
      return restored;
    } on FirebaseAuthException catch (error) {
      if ({
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
        'user-token-expired',
      }.contains(error.code)) {
        await _signOutSafely();
        return null;
      }
      throw _failure(error);
    }
  }

  @override
  Future<AuthResult?> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn.authenticate();
        final googleAuthentication = googleUser.authentication;
        final firebaseCredential = GoogleAuthProvider.credential(
          idToken: googleAuthentication.idToken,
        );
        credential = await _auth.signInWithCredential(firebaseCredential);
      }
      return AuthResult(
        user: _mapGoogleUser(credential.user)!,
        isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const AuthFailure('Google Sign-In could not be completed.');
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('Your session has expired.');
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn.authenticate();
        final googleAuthentication = googleUser.authentication;
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: googleAuthentication.idToken),
        );
      }
      return true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      throw const AuthFailure('Google re-authentication failed.');
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> signOut() async {
    await _signOutSafely();
  }

  Future<void> _signOutSafely() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Firebase sign-out must still run if the provider cache is absent.
      }
    }
    await _auth.signOut();
  }

  AuthUser? _mapGoogleUser(User? user) {
    if (user == null) return null;
    final usesGoogle = user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (!usesGoogle) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      providers: const {AppAuthProvider.google},
    );
  }

  AuthFailure _failure(FirebaseAuthException error) =>
      AuthFailure(switch (error.code) {
        'invalid-credential' => 'Google authentication could not be verified.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        'requires-recent-login' =>
          'Please sign in again before changing this security setting.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => 'Authentication could not be completed. Please try again.',
      }, code: error.code);
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._firestore, {BackendLogger? logger})
    : _logger = logger ?? BackendLogger.instance;

  final FirebaseFirestore _firestore;
  final BackendLogger _logger;

  DocumentReference<UserProfileDocument> _profile(String userId) =>
      FirestoreDocumentCollections.users(_firestore)
          .doc(BackendIds.requireUserId(userId));

  @override
  Stream<UserProfileDocumentData?> watchProfile(String userId) =>
      _profile(userId).snapshots().map(_profileData);

  @override
  Future<UserProfileDocumentData?> getProfile(String userId) async =>
      _profileData(await _profile(userId).get());

  @override
  Future<ProfileProvisioningResult> getOrCreateProfile(AuthUser user) =>
      _logger.trace<ProfileProvisioningResult>(
        repository: 'profile',
        operation: 'get_or_create',
        entity: 'user_profile',
        action: () => _firestore.runTransaction((transaction) async {
          final reference = _profile(user.uid);
          final snapshot = await transaction.get(reference);
          if (snapshot.exists) {
            return ProfileProvisioningResult(
              data: _profileData(snapshot)!,
              wasCreated: false,
            );
          }

          final now = DateTime.now();
          final document = UserProfileDocument.fromDomain(
            userId: user.uid,
            profile: UserProfile(
              fullName: user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : 'HealthPocket User',
              email: user.email ?? '',
              phoneNumber: '',
              stateOfResidence: '',
              memberSince: now,
              emailVerified: user.emailVerified,
            ),
            notifications: const NotificationPreferences(
              savingsReminders: true,
              familyActivity: true,
              healthReminders: true,
              productUpdates: false,
            ),
            onboardingStatus: AccountOnboardingStatus.incomplete,
            updatedAt: now,
          );
          transaction.set(
            _firestore.collection('users').doc(reference.id),
            document.toMap(
              createdAtOverride: FieldValue.serverTimestamp(),
              updatedAtOverride: FieldValue.serverTimestamp(),
            ),
          );
          return ProfileProvisioningResult(
            data: UserProfileDocumentData(
              profile: document.profile,
              notifications: document.notifications,
              kycStatus: document.kycStatus,
              onboardingStatus: document.onboardingStatus,
            ),
            wasCreated: true,
          );
        }),
      );

  @override
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
    required AccountOnboardingStatus onboardingStatus,
  }) => _logger.trace<void>(
    repository: 'profile',
    operation: 'save',
    entity: 'user_profile',
    action: () async {
      final reference = _profile(userId);
      final existing = await reference.get();
      final document = UserProfileDocument.fromDomain(
        userId: userId,
        profile: profile,
        notifications: notifications,
        onboardingStatus: onboardingStatus,
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(reference.id)
          .set(
            document.toMap(
              createdAtOverride: existing.exists
                  ? Timestamp.fromDate(existing.data()!.profile.memberSince)
                  : FieldValue.serverTimestamp(),
              updatedAtOverride: FieldValue.serverTimestamp(),
            ),
            SetOptions(merge: true),
          );
    },
  );

  UserProfileDocumentData? _profileData(
    DocumentSnapshot<UserProfileDocument> snapshot,
  ) {
    final document = snapshot.data();
    if (document == null) return null;
    return UserProfileDocumentData(
      profile: document.profile,
      notifications: document.notifications,
      kycStatus: document.kycStatus,
      onboardingStatus: document.onboardingStatus,
    );
  }
}

class FirestoreSavingsRepository implements SavingsRepository {
  FirestoreSavingsRepository(this._firestore, {BackendLogger? logger})
    : _logger = logger ?? BackendLogger.instance;

  final FirebaseFirestore _firestore;
  final BackendLogger _logger;

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
            (snapshot) =>
                snapshot.docs.isEmpty ? null : snapshot.docs.first.data().plan,
          );

  @override
  Future<PersonalHealthPocket?> getPersonalPocket(String userId) async {
    final snapshot = await FirestoreDocumentCollections.personalPockets(
      _firestore,
    ).where('userId', isEqualTo: userId).limit(1).get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.data().pocket;
  }

  @override
  Future<SavingsPlan?> getPlan(String userId) async {
    final snapshot = await FirestoreDocumentCollections.savingsPlans(_firestore)
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.data().plan;
  }

  @override
  Future<void> savePersonalPocket(
    PersonalHealthPocket pocket,
  ) => _logger.trace<void>(
    repository: 'savings',
    operation: 'save',
    entity: 'personal_pocket',
    action: () async {
      final expectedId = BackendIds.personalPocket(pocket.userId);
      if (pocket.id != expectedId) {
        throw ArgumentError.value(
          pocket.id,
          'pocket.id',
          'Unexpected pocket ID.',
        );
      }
      final reference = FirestoreDocumentCollections.personalPockets(_firestore)
          .doc(expectedId);
      // A direct read of a document that does not exist cannot prove ownership
      // from resource.data and is therefore denied by the private collection
      // rules. Querying by the authenticated owner works for both an empty first
      // result and an idempotent retry.
      final existing = await getPersonalPocket(pocket.userId);
      final persistedPocket = PersonalHealthPocket(
        id: pocket.id,
        userId: pocket.userId,
        currency: pocket.currency,
        status: pocket.status,
        createdAt: existing?.id == pocket.id
            ? existing!.createdAt
            : pocket.createdAt,
        updatedAt: pocket.updatedAt,
      );
      await _firestore
          .collection(reference.parent.path)
          .doc(reference.id)
          .set(
            PersonalHealthPocketDocument(persistedPocket).toMap(
              createdAtOverride: existing?.id == pocket.id
                  ? Timestamp.fromDate(existing!.createdAt)
                  : FieldValue.serverTimestamp(),
              updatedAtOverride: FieldValue.serverTimestamp(),
            ),
          );
    },
  );

  @override
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    String? fundingSourceId,
  }) => _logger.trace<void>(
    repository: 'savings',
    operation: 'save',
    entity: 'savings_plan',
    action: () async {
      final expectedPlanId = BackendIds.savingsPlan(userId);
      if (plan.id != expectedPlanId ||
          personalHealthPocketId != BackendIds.personalPocket(userId)) {
        throw ArgumentError('Unexpected savings ownership or identifier.');
      }
      final plans = FirestoreDocumentCollections.savingsPlans(_firestore);
      final existingSnapshot = await plans
          .where('userId', isEqualTo: userId)
          .limit(5)
          .get();
      SavingsPlanDocument? existing;
      for (final document in existingSnapshot.docs) {
        if (document.id == plan.id) {
          existing = document.data();
          break;
        }
      }
      final now = DateTime.now();
      final effectiveNextContributionDate = switch (plan.status) {
        SavingsPlanStatus.active => SavingsSchedule.nextContributionDate(
          startDate: plan.startDate,
          frequency: plan.frequency,
          after: now,
        ),
        SavingsPlanStatus.paused || SavingsPlanStatus.cancelled => null,
      };
      final document = SavingsPlanDocument(
        plan: plan,
        userId: userId,
        personalHealthPocketId: personalHealthPocketId,
        nextContributionDate: effectiveNextContributionDate,
        fundingSourceId: fundingSourceId,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _firestore
          .collection('savings_plans')
          .doc(plan.id)
          .set(
            document.toMap(
              createdAtOverride: existing == null
                  ? FieldValue.serverTimestamp()
                  : Timestamp.fromDate(existing.createdAt),
              updatedAtOverride: FieldValue.serverTimestamp(),
            ),
          );
    },
  );
}

class FirestoreContributionRepository implements ContributionRepository {
  FirestoreContributionRepository(this._firestore, {BackendLogger? logger})
    : _logger = logger ?? BackendLogger.instance;

  final FirebaseFirestore _firestore;
  final BackendLogger _logger;

  Query<ContributionDocument> _personalContributionQuery({
    required String userId,
    required String personalHealthPocketId,
  }) =>
      FirestoreDocumentCollections.contributions(_firestore)
          .where('contributorUserId', isEqualTo: userId)
          .where('personalHealthPocketId', isEqualTo: personalHealthPocketId)
          .orderBy('createdAt', descending: true);

  @override
  Future<List<ContributionRecord>> getPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  }) async {
    final snapshot = await _personalContributionQuery(
      userId: userId,
      personalHealthPocketId: personalHealthPocketId,
    ).get();
    return snapshot.docs
        .map((document) => document.data().contribution)
        .toList(growable: false);
  }

  @override
  Stream<List<ContributionRecord>> watchPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  }) =>
      _personalContributionQuery(
        userId: userId,
        personalHealthPocketId: personalHealthPocketId,
      ).snapshots().map(
        (snapshot) => snapshot.docs
            .map((document) => document.data().contribution)
            .toList(growable: false),
      );

  @override
  Stream<List<ContributionRecord>> watchFamilyContributions(
    String familyPocketId,
  ) =>
      FirestoreDocumentCollections.contributions(_firestore)
          .where('familyPocketId', isEqualTo: familyPocketId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((document) => document.data().contribution)
                .toList(growable: false),
          );

  @override
  Future<List<ContributionRecord>> getFamilyContributions(
    String familyPocketId,
  ) async {
    final snapshot =
        await FirestoreDocumentCollections.contributions(_firestore)
            .where('familyPocketId', isEqualTo: familyPocketId)
            .orderBy('createdAt', descending: true)
            .get();
    return snapshot.docs
        .map((document) => document.data().contribution)
        .toList(growable: false);
  }

  @override
  Future<void> recordDevelopmentContribution(
    ContributionRecord contribution,
  ) => _logger.trace<void>(
    repository: 'contribution',
    operation: 'create_idempotent',
    entity: 'personal_contribution',
    action: () async {
      _validateDevelopmentContribution(contribution);
      final reference = _firestore
          .collection('contributions')
          .doc(contribution.id);
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) {
          final existingData = existing.data();
          if (existingData?['contributorUserId'] !=
                  contribution.contributorUserId ||
              existingData?['idempotencyKey'] != contribution.idempotencyKey ||
              existingData?['personalHealthPocketId'] !=
                  contribution.personalHealthPocketId ||
              existingData?['savingsPlanId'] != contribution.savingsPlanId ||
              existingData?['amountKobo'] != contribution.amountKobo ||
              existingData?['currency'] != contribution.currency) {
            throw StateError(
              'The contribution idempotency key is unavailable.',
            );
          }
          return;
        }
        transaction.set(
          reference,
          ContributionDocument(contribution)
              .toMap(createdAtOverride: FieldValue.serverTimestamp()),
        );
      });
    },
  );

  @override
  Future<void> recordDevelopmentFamilyContribution(
    ContributionRecord contribution,
  ) => _logger.trace<void>(
    repository: 'contribution',
    operation: 'create_idempotent',
    entity: 'family_contribution',
    action: () async {
      _validateDevelopmentFamilyContribution(contribution);
      final reference = _firestore
          .collection('contributions')
          .doc(contribution.id);
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) {
          final existingData = existing.data();
          if (existingData?['contributorUserId'] !=
                  contribution.contributorUserId ||
              existingData?['idempotencyKey'] != contribution.idempotencyKey ||
              existingData?['familyPocketId'] != contribution.familyPocketId ||
              existingData?['amountKobo'] != contribution.amountKobo ||
              existingData?['currency'] != contribution.currency ||
              existingData?['contributorName'] !=
                  contribution.contributorName) {
            throw StateError(
              'The contribution idempotency key is unavailable.',
            );
          }
          return;
        }
        transaction.set(
          reference,
          ContributionDocument(contribution)
              .toMap(createdAtOverride: FieldValue.serverTimestamp()),
        );
      });
    },
  );

  void _validateDevelopmentContribution(ContributionRecord contribution) {
    final expectedId = BackendIds.personalContribution(
      contribution.contributorUserId,
      contribution.idempotencyKey,
    );
    if (contribution.id != expectedId ||
        contribution.personalHealthPocketId == null ||
        contribution.familyPocketId != null ||
        contribution.contributorName != null ||
        contribution.savingsPlanId == null ||
        contribution.amountKobo <= 0 ||
        contribution.amountKobo > 100000000000 ||
        contribution.currency != 'NGN' ||
        contribution.status != ContributionStatus.recorded ||
        contribution.origin != ContributionOrigin.devSimulation ||
        contribution.moneyMovement ||
        contribution.createdAt != null) {
      throw ArgumentError('Invalid development contribution record.');
    }
  }

  void _validateDevelopmentFamilyContribution(ContributionRecord contribution) {
    final expectedId = BackendIds.familyContribution(
      contribution.contributorUserId,
      contribution.idempotencyKey,
    );
    final name = contribution.contributorName;
    if (contribution.id != expectedId ||
        contribution.personalHealthPocketId != null ||
        contribution.savingsPlanId != null ||
        contribution.familyPocketId == null ||
        name == null ||
        name.trim().isEmpty ||
        name.length > 100 ||
        contribution.amountKobo <= 0 ||
        contribution.amountKobo > 100000000000 ||
        contribution.currency != 'NGN' ||
        contribution.status != ContributionStatus.recorded ||
        contribution.origin != ContributionOrigin.devSimulation ||
        contribution.moneyMovement ||
        contribution.createdAt != null) {
      throw ArgumentError('Invalid Family Pocket development contribution.');
    }
  }
}

class FirestoreFamilyPocketRepository implements FamilyPocketRepository {
  FirestoreFamilyPocketRepository(this._firestore, {BackendLogger? logger})
    : _logger = logger ?? BackendLogger.instance;

  final FirebaseFirestore _firestore;
  final BackendLogger _logger;

  @override
  Future<List<FamilyPocket>> getPocketsForUser(String userId) async {
    Query<FamilyMembershipDocument> membershipQuery(
      String statusField,
      String status,
    ) =>
        _firestore
            .collectionGroup('members')
            .where('userId', isEqualTo: userId)
            .where(statusField, isEqualTo: status)
            .orderBy('joinedAt', descending: true)
            .withConverter<FamilyMembershipDocument>(
              fromFirestore: (snapshot, _) => FamilyMembershipDocument.fromMap(
                snapshot.id,
                snapshot.data()!,
              ),
              toFirestore: (document, _) => document.toMap(),
            );
    final membershipSnapshots = await Future.wait([
      membershipQuery('status', 'active').get(),
      membershipQuery('status', 'accepted').get(),
      membershipQuery('invitationStatus', 'accepted').get(),
    ]);
    final membershipDocuments = {
      for (final snapshot in membershipSnapshots)
        for (final document in snapshot.docs) document.reference.path: document,
    }.values;

    final pockets = await Future.wait(
      membershipDocuments.map((ownMembershipDocument) async {
        final ownMembership = ownMembershipDocument.data().membership;
        final pocketDocument = await FirestoreDocumentCollections.familyPockets(
          _firestore,
        ).doc(ownMembership.pocketId).get();
        final pocket = pocketDocument.data()?.pocket;
        if (pocket == null) return null;

        final memberSnapshot = await FirestoreDocumentCollections.familyMembers(
          _firestore,
          pocket.id,
        ).get();
        final members = memberSnapshot.docs
            .map((document) => document.data().membership)
            .where(
              (membership) =>
                  membership.status == FamilyMembershipStatus.active ||
                  membership.status == FamilyMembershipStatus.accepted,
            )
            .map(
              (membership) => FamilyMember(
                id: membership.id,
                name: membership.name,
                role: membership.role,
                canContribute: membership.canContribute,
                isBeneficiary: membership.isBeneficiary,
                beneficiarySlot: membership.beneficiarySlot,
              ),
            )
            .toList();

        var invitations = const <FamilyInvitation>[];
        if (ownMembership.role == FamilyRole.owner ||
            ownMembership.role == FamilyRole.admin) {
          final inviteSnapshot =
              await FirestoreDocumentCollections.familyInvitations(
                _firestore,
                pocket.id,
              ).orderBy('createdAt', descending: true).get();
          invitations = inviteSnapshot.docs
              .map((document) => document.data().invitation)
              .toList(growable: false);
        }
        return pocket.copyWith(members: members, invitations: invitations);
      }),
    );
    return pockets.whereType<FamilyPocket>().toList(growable: false);
  }

  @override
  Future<List<FamilyInvitation>> getPendingInvitationsForEmail(
    String email,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return const [];
    final snapshot = await _firestore
        .collectionGroup('invites')
        .where('email', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: FamilyInvitationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .withConverter<FamilyInvitationDocument>(
          fromFirestore: (snapshot, _) =>
              FamilyInvitationDocument.fromMap(snapshot.id, snapshot.data()!),
          toFirestore: (document, _) => document.toMap(),
        )
        .get();
    return snapshot.docs
        .map((document) => document.data().invitation)
        .where(
          (invitation) =>
              invitation.effectiveStatus == FamilyInvitationStatus.pending,
        )
        .toList(growable: false);
  }

  @override
  Stream<FamilyPocket?> watchPocket(String pocketId) =>
      FirestoreDocumentCollections.familyPockets(_firestore)
          .doc(pocketId)
          .snapshots()
          .map((snapshot) => snapshot.data()?.pocket);

  @override
  Stream<List<FamilyMembership>> watchMembers(String pocketId) =>
      FirestoreDocumentCollections.familyMembers(_firestore, pocketId)
          .where('status', whereIn: const ['active', 'accepted'])
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
          .where('status', whereIn: const ['active', 'accepted'])
          .orderBy('joinedAt', descending: true)
          .withConverter<FamilyMembershipDocument>(
            fromFirestore: (snapshot, _) =>
                FamilyMembershipDocument.fromMap(snapshot.id, snapshot.data()!),
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
  }) => _logger.trace<void>(
    repository: 'family_pocket',
    operation: 'create',
    entity: 'family_pocket',
    action: () async {
      if (!BackendIds.isFamilyPocketForUser(pocket.id, createdBy)) {
        throw ArgumentError.value(
          pocket.id,
          'pocket.id',
          'Unexpected pocket ID.',
        );
      }
      if (adminMembership.id != createdBy ||
          adminMembership.userId != createdBy ||
          adminMembership.pocketId != pocket.id ||
          adminMembership.role != FamilyRole.owner ||
          adminMembership.status != FamilyMembershipStatus.accepted ||
          !adminMembership.canContribute ||
          adminMembership.isBeneficiary) {
        throw ArgumentError(
          'The founding membership must be the accepted admin.',
        );
      }
      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.set<Map<String, Object?>>(
        _firestore.collection('family_pockets').doc(pocket.id),
        FamilyPocketDocument(
          pocket: pocket,
          createdBy: createdBy,
          currency: 'NGN',
          status: FamilyPocketStatus.active,
          createdAt: now,
          updatedAt: now,
        ).toMap(
          createdAtOverride: FieldValue.serverTimestamp(),
          updatedAtOverride: FieldValue.serverTimestamp(),
        ),
      );
      batch.set<Map<String, Object?>>(
        _firestore
            .collection('family_pockets')
            .doc(pocket.id)
            .collection('members')
            .doc(adminMembership.id),
        FamilyMembershipDocument(adminMembership)
            .toMap(joinedAtOverride: FieldValue.serverTimestamp()),
      );
      await batch.commit();
    },
  );

  @override
  Future<void> createInvitation(FamilyInvitation invitation) =>
      _logger.trace<void>(
        repository: 'family_pocket',
        operation: 'create',
        entity: 'invitation',
        action: () async {
          if (!BackendIds.isInvitationForUser(
            invitation.id,
            invitation.createdBy,
          )) {
            throw ArgumentError.value(
              invitation.id,
              'invitation.id',
              'Unexpected invitation ID.',
            );
          }
          if (invitation.status != FamilyInvitationStatus.pending ||
              (!invitation.canContribute && !invitation.isBeneficiary) ||
              invitation.email != invitation.email.toLowerCase() ||
              invitation.expiresAt.isBefore(DateTime.now())) {
            throw ArgumentError('Invalid Family Pocket invitation.');
          }
          final duplicate = await _firestore
              .collection('family_pockets')
              .doc(invitation.pocketId)
              .collection('invites')
              .where('email', isEqualTo: invitation.email)
              .where('status', isEqualTo: FamilyInvitationStatus.pending.name)
              .limit(1)
              .get();
          if (duplicate.docs.isNotEmpty) {
            throw StateError('This person already has a pending invitation.');
          }

          final pocketReference = _firestore
              .collection('family_pockets')
              .doc(invitation.pocketId);
          final invitationReference = pocketReference
              .collection('invites')
              .doc(invitation.id);
          await _firestore.runTransaction((transaction) async {
            int? beneficiarySlot;
            DocumentReference<Map<String, dynamic>>? slotReference;
            if (invitation.isBeneficiary) {
              final first = pocketReference
                  .collection('beneficiary_slots')
                  .doc('1');
              final second = pocketReference
                  .collection('beneficiary_slots')
                  .doc('2');
              final firstSnapshot = await transaction.get(first);
              final secondSnapshot = await transaction.get(second);
              if (!firstSnapshot.exists) {
                beneficiarySlot = 1;
                slotReference = first;
              } else if (!secondSnapshot.exists) {
                beneficiarySlot = 2;
                slotReference = second;
              } else {
                throw StateError(
                  'This pocket already has two beneficiary slots.',
                );
              }
            }
            final storedInvitation = FamilyInvitation(
              id: invitation.id,
              pocketId: invitation.pocketId,
              pocketName: invitation.pocketName,
              inviteeName: invitation.inviteeName,
              email: invitation.email,
              inviterName: invitation.inviterName,
              canContribute: invitation.canContribute,
              isBeneficiary: invitation.isBeneficiary,
              beneficiarySlot: beneficiarySlot,
              status: invitation.status,
              createdBy: invitation.createdBy,
              createdAt: invitation.createdAt,
              expiresAt: invitation.expiresAt,
            );
            transaction.set(
              invitationReference,
              FamilyInvitationDocument(storedInvitation)
                  .toMap(createdAtOverride: FieldValue.serverTimestamp()),
            );
            if (slotReference != null) {
              transaction.set(slotReference, {
                'pocketId': invitation.pocketId,
                'slot': beneficiarySlot,
                'state': 'reserved',
                'invitationId': invitation.id,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          });
        },
      );

  @override
  Future<void> respondToInvitation({
    required FamilyInvitation invitation,
    required String userId,
    required String userName,
    required bool accept,
  }) => _logger.trace<void>(
    repository: 'family_pocket',
    operation: accept ? 'accept_invitation' : 'decline_invitation',
    entity: 'invitation',
    action: () async {
      final pocketReference = _firestore
          .collection('family_pockets')
          .doc(invitation.pocketId);
      final invitationReference = pocketReference
          .collection('invites')
          .doc(invitation.id);
      final memberReference = pocketReference.collection('members').doc(userId);
      final slot = invitation.beneficiarySlot;
      final slotReference = slot == null
          ? null
          : pocketReference.collection('beneficiary_slots').doc('$slot');
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(invitationReference);
        if (!current.exists || current.data()?['status'] != 'pending') {
          throw StateError('This invitation is no longer pending.');
        }
        transaction.update(invitationReference, {
          'status': accept ? 'accepted' : 'declined',
          'respondedBy': userId,
          'respondedAt': FieldValue.serverTimestamp(),
        });
        if (accept) {
          transaction.set(
            memberReference,
            FamilyMembershipDocument(
              FamilyMembership(
                id: userId,
                pocketId: invitation.pocketId,
                userId: userId,
                invitationId: invitation.id,
                name: userName,
                role: FamilyRole.member,
                canContribute: invitation.canContribute,
                isBeneficiary: invitation.isBeneficiary,
                beneficiarySlot: slot,
                status: FamilyMembershipStatus.accepted,
                joinedAt: null,
              ),
            ).toMap(joinedAtOverride: FieldValue.serverTimestamp()),
          );
          if (slotReference != null) {
            transaction.update(slotReference, {
              'state': 'accepted',
              'memberUserId': userId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else if (slotReference != null) {
          transaction.delete(slotReference);
        }
      });
    },
  );

  @override
  Future<void> cancelInvitation(FamilyInvitation invitation) =>
      _logger.trace<void>(
        repository: 'family_pocket',
        operation: 'cancel_invitation',
        entity: 'invitation',
        action: () async {
          final pocketReference = _firestore
              .collection('family_pockets')
              .doc(invitation.pocketId);
          final batch = _firestore.batch();
          batch.update(
            pocketReference.collection('invites').doc(invitation.id),
            {
              'status': FamilyInvitationStatus.cancelled.name,
              'respondedBy': invitation.createdBy,
              'respondedAt': FieldValue.serverTimestamp(),
            },
          );
          final slot = invitation.beneficiarySlot;
          if (slot != null) {
            batch.delete(
              pocketReference.collection('beneficiary_slots').doc('$slot'),
            );
          }
          await batch.commit();
        },
      );

  @override
  Future<void> markMemberRemoved({
    required String pocketId,
    required String memberId,
    required bool wasBeneficiary,
    int? beneficiarySlot,
  }) => _logger.trace<void>(
    repository: 'family_pocket',
    operation: 'remove_member',
    entity: 'membership',
    action: () async {
      final pocketReference = _firestore
          .collection('family_pockets')
          .doc(pocketId);
      final batch = _firestore.batch();
      batch.update(pocketReference.collection('members').doc(memberId), {
        'status': FamilyMembershipStatus.removed.name,
        'removedAt': FieldValue.serverTimestamp(),
      });
      if (wasBeneficiary && beneficiarySlot != null) {
        batch.delete(
          pocketReference
              .collection('beneficiary_slots')
              .doc('$beneficiarySlot'),
        );
      }
      await batch.commit();
    },
  );
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

class FirestoreWalletRepository implements WalletRepository {
  FirestoreWalletRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<WalletAccount?> watchWallet(String userId) =>
      FirestoreDocumentCollections.wallets(_firestore)
          .doc(BackendIds.requireUserId(userId))
          .snapshots()
          .map((snapshot) => snapshot.data()?.wallet);

  @override
  Future<WalletAccount?> getWallet(String userId) async =>
      (await FirestoreDocumentCollections.wallets(
        _firestore,
      ).doc(BackendIds.requireUserId(userId)).get()).data()?.wallet;

  @override
  Future<List<LedgerEntry>> getLedgerEntries({
    required String userId,
    int limit = 50,
  }) async {
    final safeUserId = BackendIds.requireUserId(userId);
    final safeLimit = _validatedLimit(limit);
    final snapshot =
        await FirestoreDocumentCollections.ledgerEntries(_firestore)
            .where('userId', isEqualTo: safeUserId)
            .orderBy('createdAt', descending: true)
            .limit(safeLimit)
            .get();
    return snapshot.docs
        .map((document) => document.data().entry)
        .toList(growable: false);
  }

  @override
  Future<List<FinancialOperation>> getFinancialOperations({
    required String userId,
    int limit = 50,
  }) async {
    final safeUserId = BackendIds.requireUserId(userId);
    final safeLimit = _validatedLimit(limit);
    final snapshot =
        await FirestoreDocumentCollections.financialOperations(_firestore)
            .where('userId', isEqualTo: safeUserId)
            .orderBy('createdAt', descending: true)
            .limit(safeLimit)
            .get();
    return snapshot.docs
        .map((document) => document.data().operation)
        .toList(growable: false);
  }

  int _validatedLimit(int value) {
    if (value < 1 || value > 100) {
      throw RangeError.range(value, 1, 100, 'limit');
    }
    return value;
  }
}

class FirestoreFundingRepository implements FundingRepository {
  FirestoreFundingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<FundingTransaction>> watchFundingTransactions({
    required String userId,
    int limit = 50,
  }) {
    final safeUserId = BackendIds.requireUserId(userId);
    final safeLimit = _validatedFundingLimit(limit);
    return FirestoreDocumentCollections.fundingTransactions(_firestore)
        .where('userId', isEqualTo: safeUserId)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => document.data().transaction)
              .toList(growable: false),
        );
  }

  @override
  Future<FundingTransaction?> getFundingTransaction({
    required String userId,
    required String transactionId,
  }) async {
    final safeUserId = BackendIds.requireUserId(userId);
    final safeTransactionId = BackendIds.requireSafe(transactionId);
    final transaction = (
      await FirestoreDocumentCollections.fundingTransactions(
        _firestore,
      ).doc(safeTransactionId).get()
    ).data()?.transaction;
    if (transaction == null) return null;
    if (transaction.userId != safeUserId) {
      throw StateError('Funding transaction owner mismatch.');
    }
    return transaction;
  }

  int _validatedFundingLimit(int value) {
    if (value < 1 || value > 100) {
      throw RangeError.range(value, 1, 100, 'limit');
    }
    return value;
  }
}

class FirebaseRepositoryBundle {
  FirebaseRepositoryBundle({
    required this.auth,
    required FirebaseFirestore firestore,
    BackendLogger? logger,
  }) : profiles = FirestoreProfileRepository(firestore, logger: logger),
       savings = FirestoreSavingsRepository(firestore, logger: logger),
       contributions = FirestoreContributionRepository(
         firestore,
         logger: logger,
       ),
       familyPockets = FirestoreFamilyPocketRepository(
         firestore,
         logger: logger,
       ),
       wallets = FirestoreWalletRepository(firestore),
       funding = FirestoreFundingRepository(firestore),
       activities = FirestoreActivityRepository(firestore);

  final AuthRepository auth;
  final ProfileRepository profiles;
  final SavingsRepository savings;
  final ContributionRepository contributions;
  final FamilyPocketRepository familyPockets;
  final WalletRepository wallets;
  final FundingRepository funding;
  final ActivityRepository activities;
}
