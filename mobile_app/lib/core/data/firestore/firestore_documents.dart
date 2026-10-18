import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthpocket/core/data/firestore/firestore_serialization.dart';
import 'package:healthpocket/features/activity/domain/activity_record.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/funding/domain/funding_transaction.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/wallet/domain/wallet_account.dart';

class UserProfileDocument {
  const UserProfileDocument({
    required this.id,
    required this.userId,
    required this.profile,
    required this.notifications,
    required this.kycStatus,
    required this.onboardingStatus,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final UserProfile profile;
  final NotificationPreferences notifications;
  final KycStatus kycStatus;
  final AccountOnboardingStatus onboardingStatus;
  final DateTime updatedAt;

  factory UserProfileDocument.fromDomain({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
    required AccountOnboardingStatus onboardingStatus,
    required DateTime updatedAt,
  }) {
    return UserProfileDocument(
      id: userId,
      userId: userId,
      profile: profile.copyWith(updatedAt: updatedAt),
      notifications: notifications,
      onboardingStatus: onboardingStatus,
      kycStatus: profile.demoKycComplete
          ? KycStatus.demoComplete
          : KycStatus.notStarted,
      updatedAt: updatedAt,
    );
  }

  factory UserProfileDocument.fromMap(String id, Map<String, dynamic> data) {
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
        updatedAt: firestoreDateTime(data, 'updatedAt'),
        profileImagePath: firestoreNullableString(data, 'profileImagePath'),
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
      // Profiles written before onboardingStatus was introduced represent
      // beta users who had already passed the old onboarding gate.
      onboardingStatus: data['onboardingStatus'] == null
          ? AccountOnboardingStatus.complete
          : firestoreEnum(
              data,
              'onboardingStatus',
              AccountOnboardingStatus.values,
            ),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap({
    Object? createdAtOverride,
    Object? updatedAtOverride,
  }) => {
    'userId': userId,
    'fullName': profile.fullName,
    'email': profile.email,
    'phoneNumber': profile.phoneNumber,
    'stateOfResidence': profile.stateOfResidence,
    'profileImagePath': profile.profileImagePath,
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
    'onboardingStatus': onboardingStatus.name,
    'notificationPreferences': {
      'savingsReminders': notifications.savingsReminders,
      'familyActivity': notifications.familyActivity,
      'healthReminders': notifications.healthReminders,
      'productUpdates': notifications.productUpdates,
    },
    'createdAt': createdAtOverride ?? firestoreTimestamp(profile.memberSince),
    'updatedAt': updatedAtOverride ?? firestoreTimestamp(updatedAt),
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

  Map<String, Object?> toMap({
    Object? createdAtOverride,
    Object? updatedAtOverride,
  }) => {
    'userId': pocket.userId,
    'currency': pocket.currency,
    'status': pocket.status.name,
    'createdAt': createdAtOverride ?? firestoreTimestamp(pocket.createdAt),
    'updatedAt': updatedAtOverride ?? firestoreTimestamp(pocket.updatedAt),
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

  factory SavingsPlanDocument.fromMap(String id, Map<String, dynamic> data) {
    final legacyAmountNaira = data['contributionAmount'];
    final amountKobo =
        data['contributionAmountKobo'] ??
        (legacyAmountNaira is int ? legacyAmountNaira * 100 : null);
    if (amountKobo is! int) {
      throw const FormatException('Expected integer "contributionAmountKobo".');
    }
    return SavingsPlanDocument(
      plan: SavingsPlan(
        id: id,
        contributionAmountKobo: amountKobo,
        frequency: firestoreEnum(data, 'frequency', SavingsFrequency.values),
        startDate: firestoreDateTime(data, 'startDate'),
        status: firestoreEnum(data, 'status', SavingsPlanStatus.values),
      ),
      userId: firestoreString(data, 'userId'),
      personalHealthPocketId: firestoreString(data, 'personalHealthPocketId'),
      nextContributionDate: firestoreNullableDateTime(
        data,
        'nextContributionDate',
      ),
      fundingSourceId: firestoreNullableString(data, 'fundingSourceId'),
      createdAt: firestoreDateTime(data, 'createdAt'),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap({
    Object? createdAtOverride,
    Object? updatedAtOverride,
  }) => {
    'userId': userId,
    'personalHealthPocketId': personalHealthPocketId,
    'contributionAmountKobo': plan.contributionAmountKobo,
    'frequency': plan.frequency.name,
    'startDate': firestoreTimestamp(plan.startDate),
    'nextContributionDate': nextContributionDate == null
        ? null
        : firestoreTimestamp(nextContributionDate!),
    'status': plan.status.name,
    'fundingSourceId': fundingSourceId,
    'createdAt': createdAtOverride ?? firestoreTimestamp(createdAt),
    'updatedAt': updatedAtOverride ?? firestoreTimestamp(updatedAt),
  };
}

class ContributionDocument {
  const ContributionDocument(this.contribution);

  final ContributionRecord contribution;

  factory ContributionDocument.fromMap(String id, Map<String, dynamic> data) {
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
        contributorName: firestoreNullableString(data, 'contributorName'),
        amountKobo: firestoreInt(data, 'amountKobo'),
        currency: firestoreString(data, 'currency'),
        status: firestoreEnum(data, 'status', ContributionStatus.values),
        origin: ContributionOrigin.fromFirestore(
          firestoreString(data, 'origin'),
        ),
        moneyMovement: firestoreBool(data, 'moneyMovement'),
        idempotencyKey: firestoreString(data, 'idempotencyKey'),
        note: firestoreNullableString(data, 'note'),
        createdAt: firestoreNullableDateTime(data, 'createdAt'),
      ),
    );
  }

  Map<String, Object?> toMap({Object? createdAtOverride}) {
    final data = <String, Object?>{
      'contributorUserId': contribution.contributorUserId,
      'amountKobo': contribution.amountKobo,
      'currency': contribution.currency,
      'status': contribution.status.name,
      'origin': contribution.origin.firestoreValue,
      'moneyMovement': contribution.moneyMovement,
      'idempotencyKey': contribution.idempotencyKey,
      'createdAt':
          createdAtOverride ??
          (contribution.createdAt == null
              ? null
              : firestoreTimestamp(contribution.createdAt!)),
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
    if (contribution.contributorName case final name?) {
      data['contributorName'] = name;
    }
    if (contribution.note case final note?) data['note'] = note;
    return data;
  }
}

class WalletAccountDocument {
  const WalletAccountDocument(this.wallet);

  final WalletAccount wallet;

  factory WalletAccountDocument.fromMap(String id, Map<String, dynamic> data) =>
      WalletAccountDocument(
        WalletAccount(
          id: id,
          userId: firestoreString(data, 'userId'),
          currency: firestoreString(data, 'currency'),
          availableBalanceKobo: firestoreInt(data, 'availableBalanceKobo'),
          status: firestoreEnum(data, 'status', WalletStatus.values),
          version: firestoreInt(data, 'version'),
          createdAt: firestoreDateTime(data, 'createdAt'),
          updatedAt: firestoreDateTime(data, 'updatedAt'),
        ),
      );
}

class LedgerEntryDocument {
  const LedgerEntryDocument(this.entry);

  final LedgerEntry entry;

  factory LedgerEntryDocument.fromMap(String id, Map<String, dynamic> data) =>
      LedgerEntryDocument(
        LedgerEntry(
          id: id,
          operationId: firestoreString(data, 'operationId'),
          userId: firestoreString(data, 'userId'),
          walletId: firestoreString(data, 'walletId'),
          direction: firestoreEnum(data, 'direction', LedgerDirection.values),
          amountKobo: firestoreInt(data, 'amountKobo'),
          currency: firestoreString(data, 'currency'),
          status: firestoreEnum(data, 'status', LedgerEntryStatus.values),
          source: FinancialSource.fromFirestore(
            firestoreString(data, 'source'),
          ),
          createdAt: firestoreDateTime(data, 'createdAt'),
          providerReference: firestoreNullableString(data, 'providerReference'),
          familyPocketId: firestoreNullableString(data, 'familyPocketId'),
          reversesLedgerEntryId: firestoreNullableString(
            data,
            'reversesLedgerEntryId',
          ),
        ),
      );
}

class FinancialOperationDocument {
  const FinancialOperationDocument(this.operation);

  final FinancialOperation operation;

  factory FinancialOperationDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) => FinancialOperationDocument(
    FinancialOperation(
      id: id,
      userId: firestoreString(data, 'userId'),
      walletId: firestoreString(data, 'walletId'),
      direction: firestoreEnum(data, 'direction', LedgerDirection.values),
      amountKobo: firestoreInt(data, 'amountKobo'),
      currency: firestoreString(data, 'currency'),
      status: firestoreEnum(data, 'status', FinancialOperationStatus.values),
      source: FinancialSource.fromFirestore(firestoreString(data, 'source')),
      createdAt: firestoreDateTime(data, 'createdAt'),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
      ledgerEntryId: firestoreNullableString(data, 'ledgerEntryId'),
      failureCode: firestoreNullableString(data, 'failureCode'),
      providerReference: firestoreNullableString(data, 'providerReference'),
      familyPocketId: firestoreNullableString(data, 'familyPocketId'),
    ),
  );
}

class FundingTransactionDocument {
  const FundingTransactionDocument(this.transaction);

  final FundingTransaction transaction;

  factory FundingTransactionDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) => FundingTransactionDocument(
    FundingTransaction(
      id: id,
      userId: firestoreString(data, 'userId'),
      paymentAttemptId: firestoreString(data, 'paymentAttemptId'),
      amountKobo: firestoreInt(data, 'amountKobo'),
      currency: firestoreString(data, 'currency'),
      status: firestoreEnum(data, 'status', FundingTransactionStatus.values),
      provider: firestoreString(data, 'provider'),
      providerReference: firestoreNullableString(data, 'providerReference'),
      ledgerOperationId: firestoreNullableString(data, 'ledgerOperationId'),
      failureCode: firestoreNullableString(data, 'failureCode'),
      transactionReference: firestoreString(data, 'transactionReference'),
      receiptNumber: firestoreNullableString(data, 'receiptNumber'),
      description: firestoreString(data, 'description'),
      channel: firestoreString(data, 'channel'),
      createdAt: firestoreDateTime(data, 'createdAt'),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
      completedAt: firestoreNullableDateTime(data, 'completedAt'),
    ),
  );
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

  factory FamilyPocketDocument.fromMap(String id, Map<String, dynamic> data) {
    return FamilyPocketDocument(
      pocket: FamilyPocket(
        id: id,
        name: firestoreString(data, 'name'),
        members: const [],
        beneficiaryLimit: data['beneficiaryLimit'] is int
            ? data['beneficiaryLimit'] as int
            : 2,
        description: firestoreNullableString(data, 'description'),
        imagePath: firestoreNullableString(data, 'imagePath'),
        frequency: data['frequency'] == null
            ? FamilyContributionFrequency.monthly
            : firestoreEnum(
                data,
                'frequency',
                FamilyContributionFrequency.values,
              ),
        defaultContributionAmountKobo:
            data['defaultContributionAmountKobo'] as int? ?? 50000,
        ownerId:
            firestoreNullableString(data, 'ownerId') ??
            firestoreNullableString(data, 'createdBy'),
        currency: data['currency'] as String? ?? 'NGN',
        status: firestoreEnum(data, 'status', FamilyPocketStatus.values),
        balanceKobo: data['balanceKobo'] as int? ?? 0,
        createdAt: firestoreNullableDateTime(data, 'createdAt'),
        updatedAt: firestoreNullableDateTime(data, 'updatedAt'),
      ),
      createdBy: firestoreString(data, 'createdBy'),
      currency: firestoreString(data, 'currency'),
      status: firestoreEnum(data, 'status', FamilyPocketStatus.values),
      createdAt: firestoreDateTime(data, 'createdAt'),
      updatedAt: firestoreDateTime(data, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap({
    Object? createdAtOverride,
    Object? updatedAtOverride,
  }) => {
    'name': pocket.name,
    'description': pocket.description,
    'imagePath': pocket.imagePath,
    'frequency': pocket.frequency.name,
    'defaultContributionAmountKobo': pocket.defaultContributionAmountKobo,
    'ownerId': pocket.ownerId ?? createdBy,
    'beneficiaryLimit': pocket.beneficiaryLimit,
    'createdBy': createdBy,
    'currency': currency,
    'status': status.name,
    'balanceKobo': pocket.balanceKobo,
    'createdAt': createdAtOverride ?? firestoreTimestamp(createdAt),
    'updatedAt': updatedAtOverride ?? firestoreTimestamp(updatedAt),
  };
}

class FamilyMembershipDocument {
  const FamilyMembershipDocument(this.membership);

  final FamilyMembership membership;

  factory FamilyMembershipDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final encodedRole = firestoreString(data, 'role');
    final role = switch (encodedRole) {
      'owner' => FamilyRole.owner,
      'admin' => FamilyRole.admin,
      _ => FamilyRole.member,
    };
    final encodedStatus = data['status'] ?? data['invitationStatus'];
    final status = FamilyMembershipStatus.values.firstWhere(
      (value) => value.name == encodedStatus,
      orElse: () =>
          throw FormatException('Unknown membership status "$encodedStatus".'),
    );
    return FamilyMembershipDocument(
      FamilyMembership(
        id: id,
        pocketId: firestoreString(data, 'pocketId'),
        userId: firestoreNullableString(data, 'userId'),
        invitationId: firestoreNullableString(data, 'invitationId'),
        name: firestoreString(data, 'name'),
        role: role,
        canContribute:
            (data['permissions'] as Map<String, dynamic>?)?['canContribute']
                as bool? ??
            data['canContribute'] as bool? ??
            (encodedRole == 'owner' ||
                encodedRole == 'admin' ||
                encodedRole == 'contributor'),
        isBeneficiary:
            data['isBeneficiary'] as bool? ?? encodedRole == 'beneficiary',
        status: status,
        beneficiarySlot: data['beneficiarySlot'] as int?,
        joinedAt: firestoreNullableDateTime(data, 'joinedAt'),
        removedAt: firestoreNullableDateTime(data, 'removedAt'),
      ),
    );
  }

  Map<String, Object?> toMap({Object? joinedAtOverride}) => {
    'pocketId': membership.pocketId,
    'userId': membership.userId,
    if (membership.invitationId != null)
      'invitationId': membership.invitationId,
    'name': membership.name,
    'role': membership.role.name,
    'canContribute': membership.canContribute,
    'isBeneficiary': membership.isBeneficiary,
    'status': membership.status.name,
    if (membership.beneficiarySlot != null)
      'beneficiarySlot': membership.beneficiarySlot,
    'joinedAt':
        joinedAtOverride ??
        (membership.joinedAt == null
            ? null
            : firestoreTimestamp(membership.joinedAt!)),
    if (membership.removedAt != null)
      'removedAt': firestoreTimestamp(membership.removedAt!),
  };
}

class FamilyInvitationDocument {
  const FamilyInvitationDocument(this.invitation);

  final FamilyInvitation invitation;

  factory FamilyInvitationDocument.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final createdAt = firestoreNullableDateTime(data, 'createdAt');
    final legacyRole = data['role'];
    return FamilyInvitationDocument(
      FamilyInvitation(
        id: id,
        pocketId: firestoreString(data, 'pocketId'),
        pocketName: data['pocketName'] as String? ?? '',
        inviteeName:
            data['inviteeName'] as String? ??
            data['name'] as String? ??
            'Family member',
        email: firestoreString(data, 'email'),
        inviterName: data['inviterName'] as String? ?? 'Family admin',
        canContribute:
            data['canContribute'] as bool? ?? legacyRole == 'contributor',
        isBeneficiary:
            data['isBeneficiary'] as bool? ?? legacyRole == 'beneficiary',
        beneficiarySlot: data['beneficiarySlot'] as int?,
        status: data['status'] == null
            ? FamilyInvitationStatus.pending
            : firestoreEnum(data, 'status', FamilyInvitationStatus.values),
        createdBy: firestoreString(data, 'createdBy'),
        createdAt: createdAt,
        expiresAt:
            firestoreNullableDateTime(data, 'expiresAt') ??
            (createdAt ?? DateTime.now()).add(const Duration(days: 7)),
        respondedBy: firestoreNullableString(data, 'respondedBy'),
        respondedAt: firestoreNullableDateTime(data, 'respondedAt'),
      ),
    );
  }

  Map<String, Object?> toMap({
    Object? createdAtOverride,
    Object? respondedAtOverride,
  }) => {
    'pocketId': invitation.pocketId,
    'pocketName': invitation.pocketName,
    'inviteeName': invitation.inviteeName,
    'email': invitation.email,
    'inviterName': invitation.inviterName,
    'role': FamilyRole.member.name,
    'canContribute': invitation.canContribute,
    'isBeneficiary': invitation.isBeneficiary,
    if (invitation.beneficiarySlot != null)
      'beneficiarySlot': invitation.beneficiarySlot,
    'status': invitation.status.name,
    'createdBy': invitation.createdBy,
    'createdAt': createdAtOverride ?? firestoreTimestamp(invitation.createdAt!),
    'expiresAt': firestoreTimestamp(invitation.expiresAt),
    if (invitation.respondedBy != null) 'respondedBy': invitation.respondedBy,
    if (invitation.respondedAt != null || respondedAtOverride != null)
      'respondedAt':
          respondedAtOverride ?? firestoreTimestamp(invitation.respondedAt!),
  };
}

class ActivityRecordDocument {
  const ActivityRecordDocument(this.activity);

  final ActivityRecord activity;

  factory ActivityRecordDocument.fromMap(String id, Map<String, dynamic> data) {
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

  Map<String, Object?> toMap({Object? createdAtOverride}) => {
    'userId': activity.userId,
    'activityType': activity.activityType,
    'metadata': activity.metadata,
    'relatedEntityType': activity.relatedEntityType,
    'relatedEntityId': activity.relatedEntityId,
    if (activity.familyPocketId != null)
      'familyPocketId': activity.familyPocketId,
    'createdAt': createdAtOverride ?? firestoreTimestamp(activity.createdAt),
  };
}

class CareProviderDocument {
  const CareProviderDocument(this.provider);

  final CareProvider provider;

  factory CareProviderDocument.fromMap(String id, Map<String, dynamic> data) {
    final coordinates = firestoreObjectMap(data, 'coordinates');
    final latitude = coordinates['latitude'];
    final longitude = coordinates['longitude'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Provider coordinates must be numeric.');
    }
    final contact = firestoreObjectMap(data, 'contact');
    final rawServices = data['services'];
    final rawImages = data['imageUrls'];
    final rawLocationCells = data['locationCell'];
    if (rawServices is! List ||
        rawImages is! List ||
        rawLocationCells is! List) {
      throw const FormatException(
        'Provider services, images and location cells must be lists.',
      );
    }
    final partnerStatus = firestoreString(data, 'partnerStatus');
    return CareProviderDocument(
      CareProvider(
        id: id,
        name: firestoreString(data, 'name'),
        state: firestoreString(data, 'state'),
        city: firestoreString(data, 'city'),
        type: firestoreEnum(data, 'category', CareProviderType.values),
        services: rawServices
            .map((value) {
              if (value is! String) {
                throw const FormatException(
                  'Provider services must be strings.',
                );
              }
              return value;
            })
            .toList(growable: false),
        address: firestoreNullableString(data, 'address'),
        openingHours: firestoreNullableString(data, 'openingInformation'),
        active: firestoreBool(data, 'active'),
        isPartner: switch (partnerStatus) {
          'partner' => true,
          'non_partner' => false,
          _ => throw FormatException(
            'Unknown provider partnerStatus "$partnerStatus".',
          ),
        },
        isDemo: false,
        coordinates: CareCoordinates(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
        ),
        contact: CareProviderContact(
          phone: contact['phone'] as String?,
          email: contact['email'] as String?,
          website: _providerUri(contact['website']),
        ),
        logoUrl: _providerUri(data['logoUrl']),
        imageUrls: rawImages
            .map(_providerUri)
            .whereType<Uri>()
            .toList(growable: false),
        locationCells: rawLocationCells
            .map((value) {
              if (value is! String) {
                throw const FormatException(
                  'Provider location cells must be strings.',
                );
              }
              return value;
            })
            .toList(growable: false),
        description: firestoreNullableString(data, 'description'),
        createdAt: firestoreNullableDateTime(data, 'createdAt'),
        updatedAt: firestoreNullableDateTime(data, 'updatedAt'),
      ),
    );
  }
}

Uri? _providerUri(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Provider URL must be a string or null.');
  }
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw FormatException('Invalid provider URL "$value".');
  }
  return uri;
}

abstract final class FirestoreDocumentCollections {
  static CollectionReference<UserProfileDocument> users(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('users')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            UserProfileDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<PersonalHealthPocketDocument> personalPockets(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('personal_health_pockets')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            PersonalHealthPocketDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<SavingsPlanDocument> savingsPlans(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('savings_plans')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            SavingsPlanDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<ContributionDocument> contributions(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('contributions')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            ContributionDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<WalletAccountDocument> wallets(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('wallets')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            WalletAccountDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (_, _) => throw UnsupportedError(
          'Wallets are server-owned and cannot be written by Flutter.',
        ),
      );

  static CollectionReference<LedgerEntryDocument> ledgerEntries(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('ledger_entries')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            LedgerEntryDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (_, _) => throw UnsupportedError(
          'Ledger entries are immutable server-owned records.',
        ),
      );

  static CollectionReference<FinancialOperationDocument> financialOperations(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('financial_operations')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            FinancialOperationDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (_, _) => throw UnsupportedError(
          'Financial operations are server-owned records.',
        ),
      );

  static CollectionReference<FundingTransactionDocument> fundingTransactions(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('funding_transactions')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            FundingTransactionDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (_, _) => throw UnsupportedError(
          'Funding transactions are server-owned records.',
        ),
      );

  static CollectionReference<FamilyPocketDocument> familyPockets(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('family_pockets')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            FamilyPocketDocument.fromMap(snapshot.id, snapshot.data()!),
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
        fromFirestore: (snapshot, _) =>
            FamilyMembershipDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<FamilyInvitationDocument> familyInvitations(
    FirebaseFirestore firestore,
    String pocketId,
  ) => firestore
      .collection('family_pockets')
      .doc(pocketId)
      .collection('invites')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            FamilyInvitationDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<ActivityRecordDocument> activities(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('activities')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            ActivityRecordDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (document, _) => document.toMap(),
      );

  static CollectionReference<CareProviderDocument> careProviders(
    FirebaseFirestore firestore,
  ) => firestore
      .collection('healthcare_providers')
      .withConverter(
        fromFirestore: (snapshot, _) =>
            CareProviderDocument.fromMap(snapshot.id, snapshot.data()!),
        toFirestore: (_, _) => throw UnsupportedError(
          'Healthcare providers are maintained by trusted admin tooling.',
        ),
      );
}
