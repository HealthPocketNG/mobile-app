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

  @override
  Stream<List<ContributionRecord>> watchPersonalContributions(
    String personalHealthPocketId,
  ) =>
      FirestoreDocumentCollections.contributions(_firestore)
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
      FirestoreDocumentCollections.contributions(_firestore)
          .doc(contribution.id),
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
      FirestoreDocumentCollections.familyPockets(_firestore)
          .doc(pocketId)
          .snapshots()
          .map((snapshot) => snapshot.data()?.pocket);

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
        adminMembership.invitationStatus != FamilyInvitationStatus.accepted) {
      throw ArgumentError(
        'The founding membership must be the accepted admin.',
      );
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
  }) => FirestoreDocumentCollections.familyMembers(_firestore, pocketId)
      .doc(memberId)
      .update({
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
