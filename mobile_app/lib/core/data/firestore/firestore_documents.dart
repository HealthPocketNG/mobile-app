import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthpocket/core/data/firestore/firestore_serialization.dart';
import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

class UserProfileDocument {
  const UserProfileDocument({
    required this.id,
    required this.userId,
    required this.profile,
    required this.notifications,
    required this.kycStatus,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final UserProfile profile;
  final NotificationPreferences notifications;
  final KycStatus kycStatus;
  final DateTime updatedAt;

  factory UserProfileDocument.fromDomain({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
    required DateTime updatedAt,
  }) {
    return UserProfileDocument(
      id: userId,
      userId: userId,
      profile: profile,
      notifications: notifications,
      kycStatus: profile.demoKycComplete
          ? KycStatus.demoComplete
          : KycStatus.notStarted,
      updatedAt: updatedAt,
    );
  }

  factory UserProfileDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final notificationData = firestoreObjectMap(
      data,
      'notificationPreferences',
    );
    final notifications = notificationData.cast<String, dynamic>();
    final kycStatus = firestoreEnum(data, 'kycStatus', KycStatus.values);
    return UserProfileDocument(
      id: id,
      userId: firestoreString(data, 'userId'),
      profile: UserProfile(
        fullName: firestoreString(data, 'fullName'),
        email: firestoreString(data, 'email'),
        phoneNumber: firestoreString(data, 'phoneNumber'),
        stateOfResidence: firestoreString(data, 'stateOfResidence'),
        memberSince: firestoreDateTime(data, 'createdAt'),
        dateOfBirth: firestoreNullableDateTime(data, 'dateOfBirth'),
        gender: firestoreNullableString(data, 'gender'),
        residentialAddress: firestoreString(data, 'residentialAddress'),
        nextOfKinName: firestoreString(data, 'nextOfKinName'),
        nextOfKinPhone: firestoreString(data, 'nextOfKinPhone'),
        emailVerified: firestoreBool(data, 'emailVerified'),
        phoneVerified: firestoreBool(data, 'phoneVerified'),
        demoKycComplete: kycStatus == KycStatus.demoComplete,
      ),
      notifications: NotificationPreferences(
        savingsReminders: firestoreBool(notifications, 'savingsReminders'),
        familyActivity: firestoreBool(notifications, 'familyActivity'),
        healthReminders: firestoreBool(notifications, 'healthReminders'),
        productUpdates: firestoreBool(notifications, 'productUpdates'),
      ),
      kycStatus: kycStatus,
      updatedAt: firestoreDateTime(data, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap() => {
    'userId': userId,
    'fullName': profile.fullName,
    'email': profile.email,
    'phoneNumber': profile.phoneNumber,
    'stateOfResidence': profile.stateOfResidence,
    'dateOfBirth': profile.dateOfBirth == null
        ? null
        : firestoreTimestamp(profile.dateOfBirth!),
    'gender': profile.gender,
    'residentialAddress': profile.residentialAddress,
    'nextOfKinName': profile.nextOfKinName,
    'nextOfKinPhone': profile.nextOfKinPhone,
    'emailVerified': profile.emailVerified,
    'phoneVerified': profile.phoneVerified,
    'kycStatus': kycStatus.name,
    'notificationPreferences': {
      'savingsReminders': notifications.savingsReminders,
      'familyActivity': notifications.familyActivity,
      'healthReminders': notifications.healthReminders,
      'productUpdates': notifications.productUpdates,
    },
    'createdAt': firestoreTimestamp(profile.memberSince),
    'updatedAt': firestoreTimestamp(updatedAt),
  };
}

class PersonalHealthPocketDocument {
  const PersonalHealthPocketDocument(this.pocket);

  final PersonalHealthPocket pocket;

  factory PersonalHealthPocketDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return PersonalHealthPocketDocument(
      PersonalHealthPocket(
        id: id,
        userId: firestoreString(data, 'userId'),
        currency: firestoreString(data, 'currency'),
        status: firestoreEnum(
          data,
          'status',
          PersonalHealthPocketStatus.values,
        ),
        createdAt: firestoreDateTime(data, 'createdAt'),
        updatedAt: firestoreDateTime(data, 'updatedAt'),
      ),
    );
  }

  Map<String, Object?> toMap() => {
    'userId': pocket.userId,
    'currency': pocket.currency,
    'status': pocket.status.name,
    'createdAt': firestoreTimestamp(pocket.createdAt),
    'updatedAt': firestoreTimestamp(pocket.updatedAt),
  };
}

class SavingsPlanDocument {
  const SavingsPlanDocument({
    required this.plan,
    required this.userId,
    required this.personalHealthPocketId,
    required this.createdAt,
    required this.updatedAt,
    this.nextContributionDate,
    this.fundingSourceId,
  });

  final SavingsPlan plan;
  final String userId;
  final String personalHealthPocketId;
  final DateTime? nextContributionDate;
  final String? fundingSourceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SavingsPlanDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return SavingsPlanDocument(
      plan: SavingsPlan(
        id: id,
        contributionAmount: firestoreInt(data, 'contributionAmount'),
        frequency: firestoreString(data, 'frequency'),
        startDate: firestoreDateTime(data, 'startDate'),
        status: firestoreEnum(data, 'status', SavingsPlanStatus.values),
      ),
      userId: firestoreString(data, 'userId'),
      personalHealthPocketId: firestoreString(
        data,
        'personalHealthPocketId',
      ),
      nextContributionDate: firestoreNullableDateTime(
        data,
        'nextContributionDate',
      ),
      fundingSourceId: firestoreNullableString(data, 'fundingSourceId'),
      createdAt: firestoreDateTime(data, 'createdAt'),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap() => {
    'userId': userId,
    'personalHealthPocketId': personalHealthPocketId,
    'contributionAmount': plan.contributionAmount,
    'frequency': plan.frequency.toLowerCase(),
    'startDate': firestoreTimestamp(plan.startDate),
    'nextContributionDate': nextContributionDate == null
        ? null
        : firestoreTimestamp(nextContributionDate!),
    'status': plan.status.name,
    'fundingSourceId': fundingSourceId,
    'createdAt': firestoreTimestamp(createdAt),
    'updatedAt': firestoreTimestamp(updatedAt),
  };
}

class ContributionDocument {
  const ContributionDocument(this.contribution);

  final ContributionRecord contribution;

  factory ContributionDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ContributionDocument(
      ContributionRecord(
        id: id,
        contributorUserId: firestoreString(data, 'contributorUserId'),
        personalHealthPocketId: firestoreNullableString(
          data,
          'personalHealthPocketId',
        ),
        savingsPlanId: firestoreNullableString(data, 'savingsPlanId'),
        familyPocketId: firestoreNullableString(data, 'familyPocketId'),
        amount: firestoreInt(data, 'amount'),
        currency: firestoreString(data, 'currency'),
        status: firestoreEnum(data, 'status', ContributionStatus.values),
        source: firestoreEnum(data, 'source', ContributionSource.values),
        note: firestoreNullableString(data, 'note'),
        createdAt: firestoreDateTime(data, 'createdAt'),
      ),
    );
  }

  Map<String, Object?> toMap() {
    final data = <String, Object?>{
      'contributorUserId': contribution.contributorUserId,
      'amount': contribution.amount,
      'currency': contribution.currency,
      'status': contribution.status.name,
      'source': contribution.source.name,
      'createdAt': firestoreTimestamp(contribution.createdAt),
    };
    if (contribution.personalHealthPocketId case final pocketId?) {
      data['personalHealthPocketId'] = pocketId;
    }
    if (contribution.savingsPlanId case final planId?) {
      data['savingsPlanId'] = planId;
    }
    if (contribution.familyPocketId case final pocketId?) {
      data['familyPocketId'] = pocketId;
    }
    if (contribution.note case final note?) data['note'] = note;
    return data;
  }
}

class FamilyPocketDocument {
  const FamilyPocketDocument({
    required this.pocket,
    required this.createdBy,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final FamilyPocket pocket;
  final String createdBy;
  final String currency;
  final FamilyPocketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyPocketDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FamilyPocketDocument(
      pocket: FamilyPocket(
        id: id,
        name: firestoreString(data, 'name'),
        beneficiary: firestoreString(data, 'beneficiary'),
        members: const [],
      ),
      createdBy: firestoreString(data, 'createdBy'),
      currency: firestoreString(data, 'currency'),
      status: firestoreEnum(data, 'status', FamilyPocketStatus.values),
      createdAt: firestoreDateTime(data, 'createdAt'),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap() => {
    'name': pocket.name,
    'beneficiary': pocket.beneficiary,
    'createdBy': createdBy,
    'currency': currency,
    'status': status.name,
    'createdAt': firestoreTimestamp(createdAt),
    'updatedAt': firestoreTimestamp(updatedAt),
  };
}

class FamilyMembershipDocument {
  const FamilyMembershipDocument(this.membership);

  final FamilyMembership membership;

  factory FamilyMembershipDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FamilyMembershipDocument(
      FamilyMembership(
        id: id,
        pocketId: firestoreString(data, 'pocketId'),
        userId: firestoreNullableString(data, 'userId'),
        name: firestoreString(data, 'name'),
        email: firestoreString(data, 'email'),
        role: firestoreEnum(data, 'role', FamilyRole.values),
        invitationStatus: firestoreEnum(
          data,
          'invitationStatus',
          FamilyInvitationStatus.values,
        ),
        joinedAt: firestoreNullableDateTime(data, 'joinedAt'),
        removedAt: firestoreNullableDateTime(data, 'removedAt'),
      ),
    );
  }

  Map<String, Object?> toMap() => {
    'pocketId': membership.pocketId,
    'userId': membership.userId,
    'name': membership.name,
    'email': membership.email,
    'role': membership.role.name,
    'invitationStatus': membership.invitationStatus.name,
    'joinedAt': membership.joinedAt == null
        ? null
        : firestoreTimestamp(membership.joinedAt!),
    if (membership.removedAt != null)
      'removedAt': firestoreTimestamp(membership.removedAt!),
  };
}

class ActivityRecordDocument {
  const ActivityRecordDocument(this.activity);

  final ActivityRecord activity;

  factory ActivityRecordDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ActivityRecordDocument(
      ActivityRecord(
        id: id,
        userId: firestoreString(data, 'userId'),
        activityType: firestoreString(data, 'activityType'),
        metadata: firestoreObjectMap(data, 'metadata'),
        relatedEntityType: firestoreString(data, 'relatedEntityType'),
        relatedEntityId: firestoreString(data, 'relatedEntityId'),
        familyPocketId: firestoreNullableString(data, 'familyPocketId'),
        createdAt: firestoreDateTime(data, 'createdAt'),
      ),
    );
  }

  Map<String, Object?> toMap() => {
    'userId': activity.userId,
    'activityType': activity.activityType,
    'metadata': activity.metadata,
    'relatedEntityType': activity.relatedEntityType,
    'relatedEntityId': activity.relatedEntityId,
    if (activity.familyPocketId != null)
      'familyPocketId': activity.familyPocketId,
    'createdAt': firestoreTimestamp(activity.createdAt),
  };
}

abstract final class FirestoreDocumentCollections {
  static CollectionReference<UserProfileDocument> users(
    FirebaseFirestore firestore,
  ) => firestore.collection('users').withConverter(
    fromFirestore: (snapshot, _) => UserProfileDocument.fromMap(
      snapshot.id,
      snapshot.data()!,
    ),
    toFirestore: (document, _) => document.toMap(),
  );

  static CollectionReference<PersonalHealthPocketDocument> personalPockets(
    FirebaseFirestore firestore,
  ) => firestore.collection('personal_health_pockets').withConverter(
    fromFirestore: (snapshot, _) => PersonalHealthPocketDocument.fromMap(
      snapshot.id,
      snapshot.data()!,
    ),
    toFirestore: (document, _) => document.toMap(),
  );

  static CollectionReference<SavingsPlanDocument> savingsPlans(
    FirebaseFirestore firestore,
  ) => firestore.collection('savings_plans').withConverter(
    fromFirestore: (snapshot, _) => SavingsPlanDocument.fromMap(
      snapshot.id,
      snapshot.data()!,
    ),
    toFirestore: (document, _) => document.toMap(),
  );

  static CollectionReference<ContributionDocument> contributions(
    FirebaseFirestore firestore,
  ) => firestore.collection('contributions').withConverter(
    fromFirestore: (snapshot, _) => ContributionDocument.fromMap(
      snapshot.id,
      snapshot.data()!,
    ),
    toFirestore: (document, _) => document.toMap(),
  );

  static CollectionReference<FamilyPocketDocument> familyPockets(
    FirebaseFirestore firestore,
  ) => firestore.collection('family_pockets').withConverter(
    fromFirestore: (snapshot, _) => FamilyPocketDocument.fromMap(
      snapshot.id,
      snapshot.data()!,
    ),
    toFirestore: (document, _) => document.toMap(),
  );

  static CollectionReference<FamilyMembershipDocument> familyMembers(
    FirebaseFirestore firestore,
    String pocketId,
  ) => firestore
      .collection('family_pockets')
      .doc(pocketId)
      .collection('members')
      .withConverter(
        fromFirestore: (snapshot, _) => FamilyMembershipDocument.fromMap(
          snapshot.id,
          snapshot.data()!,
        ),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<ActivityRecordDocument> activities(
    FirebaseFirestore firestore,
  ) => firestore.collection('activities').withConverter(
    fromFirestore: (snapshot, _) => ActivityRecordDocument.fromMap(
      snapshot.id,
      snapshot.data()!,
    ),
    toFirestore: (document, _) => document.toMap(),
  );
}
