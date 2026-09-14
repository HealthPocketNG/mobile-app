import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:healthpocket/core/data/firestore/firestore_documents.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

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
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<AuthUser?> watchUser() => _auth.userChanges().map(_mapUser);

  @override
  Future<bool> hasActiveSession() async => _auth.currentUser != null;

  @override
  Future<AuthResult> createAccountWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.sendEmailVerification();
      await credential.user!.reload();
      return AuthResult(user: _mapUser(_auth.currentUser)!, isNewUser: true);
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(
        user: _mapUser(credential.user)!,
        isNewUser: credential.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (error) {
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
        user: _mapUser(credential.user)!,
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
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('Your session has expired.');
      if (!user.emailVerified) await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user?.emailVerified == true) {
        // Firestore rules read email_verified from the ID token, so refresh it
        // immediately after the user confirms their email.
        await user!.getIdToken(true);
      }
      return _mapUser(user);
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Password re-authentication is unavailable.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
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
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    final providers = <AppAuthProvider>{};
    for (final provider in user.providerData) {
      switch (provider.providerId) {
        case 'password':
          providers.add(AppAuthProvider.password);
        case 'google.com':
          providers.add(AppAuthProvider.google);
        case 'phone':
          providers.add(AppAuthProvider.phone);
      }
    }
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      providers: Set.unmodifiable(providers),
    );
  }

  AuthFailure _failure(
    FirebaseAuthException error,
  ) => AuthFailure(switch (error.code) {
    'email-already-in-use' => 'An account already uses that email address.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'wrong-password' ||
    'invalid-credential' => 'The email address or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'requires-recent-login' =>
      'Please sign in again before changing this security setting.',
    'network-request-failed' => 'Check your internet connection and try again.',
    _ => 'Authentication could not be completed. Please try again.',
  }, code: error.code);
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
  Future<void> savePersonalPocket(PersonalHealthPocket pocket) async {
    final reference = FirestoreDocumentCollections.personalPockets(_firestore)
        .doc(pocket.id);
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
    await reference.set(PersonalHealthPocketDocument(persistedPocket));
  }

  @override
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    DateTime? nextContributionDate,
    String? fundingSourceId,
  }) async {
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
    final document = SavingsPlanDocument(
      plan: plan,
      userId: userId,
      personalHealthPocketId: personalHealthPocketId,
      nextContributionDate: nextContributionDate,
      fundingSourceId: fundingSourceId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await plans.doc(plan.id).set(document);
  }
}

class FirestoreContributionRepository implements ContributionRepository {
  FirestoreContributionRepository(this._firestore);

  final FirebaseFirestore _firestore;

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
  ) async {
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
          throw StateError('The contribution idempotency key is unavailable.');
        }
        return;
      }
      transaction.set(
        reference,
        ContributionDocument(contribution)
            .toMap(createdAtOverride: FieldValue.serverTimestamp()),
      );
    });
  }

  @override
  Future<void> recordDevelopmentFamilyContribution(
    ContributionRecord contribution,
  ) async {
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
            existingData?['contributorName'] != contribution.contributorName) {
          throw StateError('The contribution idempotency key is unavailable.');
        }
        return;
      }
      transaction.set(
        reference,
        ContributionDocument(contribution)
            .toMap(createdAtOverride: FieldValue.serverTimestamp()),
      );
    });
  }

  void _validateDevelopmentContribution(ContributionRecord contribution) {
    final expectedId =
        'dev_${contribution.contributorUserId}_${contribution.idempotencyKey}';
    final validKey = RegExp(r'^[A-Za-z0-9_-]{16,80}$');
    if (contribution.id != expectedId ||
        !validKey.hasMatch(contribution.idempotencyKey) ||
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
    final expectedId =
        'dev_family_${contribution.contributorUserId}_${contribution.idempotencyKey}';
    final validKey = RegExp(r'^[A-Za-z0-9_-]{16,80}$');
    final name = contribution.contributorName;
    if (contribution.id != expectedId ||
        !validKey.hasMatch(contribution.idempotencyKey) ||
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
  FirestoreFamilyPocketRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<FamilyPocket>> getPocketsForUser(String userId) async {
    Query<FamilyMembershipDocument> membershipQuery(String statusField) =>
        _firestore
            .collectionGroup('members')
            .where('userId', isEqualTo: userId)
            .where(statusField, isEqualTo: 'accepted')
            .orderBy('joinedAt', descending: true)
            .withConverter<FamilyMembershipDocument>(
              fromFirestore: (snapshot, _) => FamilyMembershipDocument.fromMap(
                snapshot.id,
                snapshot.data()!,
              ),
              toFirestore: (document, _) => document.toMap(),
            );
    final membershipSnapshots = await Future.wait([
      membershipQuery('status').get(),
      membershipQuery('invitationStatus').get(),
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
                  membership.status != FamilyMembershipStatus.removed,
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
        if (ownMembership.role == FamilyRole.admin) {
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
          .where('status', isEqualTo: 'accepted')
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
          .where('status', isEqualTo: 'accepted')
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
  }) {
    if (adminMembership.id != createdBy ||
        adminMembership.userId != createdBy ||
        adminMembership.pocketId != pocket.id ||
        adminMembership.role != FamilyRole.admin ||
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
    return batch.commit();
  }

  @override
  Future<void> createInvitation(FamilyInvitation invitation) async {
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
        final first = pocketReference.collection('beneficiary_slots').doc('1');
        final second = pocketReference.collection('beneficiary_slots').doc('2');
        final firstSnapshot = await transaction.get(first);
        final secondSnapshot = await transaction.get(second);
        if (!firstSnapshot.exists) {
          beneficiarySlot = 1;
          slotReference = first;
        } else if (!secondSnapshot.exists) {
          beneficiarySlot = 2;
          slotReference = second;
        } else {
          throw StateError('This pocket already has two beneficiary slots.');
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
  }

  @override
  Future<void> respondToInvitation({
    required FamilyInvitation invitation,
    required String userId,
    required String userName,
    required bool accept,
  }) async {
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
  }

  @override
  Future<void> cancelInvitation(FamilyInvitation invitation) async {
    final pocketReference = _firestore
        .collection('family_pockets')
        .doc(invitation.pocketId);
    final batch = _firestore.batch();
    batch.update(pocketReference.collection('invites').doc(invitation.id), {
      'status': FamilyInvitationStatus.cancelled.name,
      'respondedBy': invitation.createdBy,
      'respondedAt': FieldValue.serverTimestamp(),
    });
    final slot = invitation.beneficiarySlot;
    if (slot != null) {
      batch.delete(
        pocketReference.collection('beneficiary_slots').doc('$slot'),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> markMemberRemoved({
    required String pocketId,
    required String memberId,
    required bool wasBeneficiary,
    int? beneficiarySlot,
  }) async {
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
        pocketReference.collection('beneficiary_slots').doc('$beneficiarySlot'),
      );
    }
    await batch.commit();
  }
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
    required this.auth,
    required FirebaseFirestore firestore,
  }) : profiles = FirestoreProfileRepository(firestore),
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
