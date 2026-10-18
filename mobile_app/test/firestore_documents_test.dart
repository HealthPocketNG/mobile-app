import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/data/firestore/firestore_documents.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/funding/domain/funding_transaction.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/wallet/domain/wallet_account.dart';

void main() {
  test('profile document round-trips the current MVP profile', () {
    final createdAt = DateTime.utc(2026, 1, 2, 10, 30);
    final updatedAt = DateTime.utc(2026, 2, 3, 9, 15);
    final profile = UserProfile(
      fullName: 'Ada Nwosu',
      email: 'ada@example.com',
      phoneNumber: '+2348012345678',
      stateOfResidence: 'Lagos',
      memberSince: createdAt,
      updatedAt: updatedAt,
      profileImagePath:
          'users/user-1/profile/0123456789abcdef0123456789abcdef.jpg',
      dateOfBirth: DateTime.utc(1993, 5, 12),
      gender: 'Female',
      residentialAddress: '12 Adeola Street',
      nextOfKinName: 'Chidi Nwosu',
      nextOfKinPhone: '+2348098765432',
      emailVerified: true,
      phoneVerified: true,
      demoKycComplete: true,
    );
    const notifications = NotificationPreferences(
      savingsReminders: true,
      familyActivity: true,
      healthReminders: false,
      productUpdates: false,
    );

    final encoded = UserProfileDocument.fromDomain(
      userId: 'user-1',
      profile: profile,
      notifications: notifications,
      onboardingStatus: AccountOnboardingStatus.complete,
      updatedAt: updatedAt,
    ).toMap();
    final decoded = UserProfileDocument.fromMap('user-1', encoded);

    expect(decoded.userId, 'user-1');
    expect(decoded.profile.fullName, profile.fullName);
    expect(decoded.profile.dateOfBirth?.toUtc(), profile.dateOfBirth);
    expect(decoded.profile.demoKycComplete, isTrue);
    expect(decoded.profile.profileImagePath, profile.profileImagePath);
    expect(decoded.profile.updatedAt?.toUtc(), updatedAt);
    expect(decoded.notifications.healthReminders, isFalse);
    expect(decoded.kycStatus, KycStatus.demoComplete);
    expect(decoded.onboardingStatus, AccountOnboardingStatus.complete);
    expect(decoded.updatedAt.toUtc(), updatedAt);
  });

  test('personal contribution encodes exactly one pocket reference', () {
    final createdAt = DateTime.utc(2026, 3, 4, 12);
    final document = ContributionDocument(
      ContributionRecord(
        id: 'contribution-1',
        contributorUserId: 'user-1',
        personalHealthPocketId: 'personal-1',
        savingsPlanId: 'plan-1',
        amountKobo: 500000,
        currency: 'NGN',
        status: ContributionStatus.recorded,
        origin: ContributionOrigin.devSimulation,
        moneyMovement: false,
        idempotencyKey: '0123456789abcdef',
        createdAt: createdAt,
      ),
    );

    final encoded = document.toMap();
    final decoded = ContributionDocument.fromMap(
      'contribution-1',
      encoded,
    ).contribution;

    expect(encoded, containsPair('personalHealthPocketId', 'personal-1'));
    expect(encoded, isNot(contains('familyPocketId')));
    expect(encoded, containsPair('amountKobo', 500000));
    expect(encoded, containsPair('origin', 'dev_simulation'));
    expect(encoded, containsPair('moneyMovement', false));
    expect(decoded.amountKobo, 500000);
    expect(decoded.createdAt?.toUtc(), createdAt);
  });

  test('savings frequency round-trips as a typed lowercase value', () {
    final createdAt = DateTime.utc(2026, 3, 1);
    final document = SavingsPlanDocument(
      plan: SavingsPlan(
        id: 'plan-1',
        contributionAmountKobo: 500000,
        frequency: SavingsFrequency.weekly,
        startDate: createdAt,
        status: SavingsPlanStatus.active,
      ),
      userId: 'user-1',
      personalHealthPocketId: 'personal-1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final encoded = document.toMap();
    final decoded = SavingsPlanDocument.fromMap('plan-1', encoded);

    expect(encoded['frequency'], 'weekly');
    expect(encoded['contributionAmountKobo'], 500000);
    expect(decoded.plan.frequency, SavingsFrequency.weekly);
    expect(decoded.plan.contributionAmountKobo, 500000);
  });

  test('legacy savings-plan naira amounts are read as kobo', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 3, 1));
    final decoded = SavingsPlanDocument.fromMap('legacy-plan', {
      'userId': 'user-1',
      'personalHealthPocketId': 'personal-1',
      'contributionAmount': 5000,
      'frequency': 'weekly',
      'startDate': timestamp,
      'nextContributionDate': null,
      'status': 'active',
      'fundingSourceId': null,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });

    expect(decoded.plan.contributionAmountKobo, 500000);
  });

  test('Family Pocket decodes authoritative settings and cached balance', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 4, 5, 8));
    final decoded = FamilyPocketDocument.fromMap('family-1', {
      'name': 'Bello Family',
      'description': 'Shared care savings',
      'imagePath': null,
      'frequency': 'weekly',
      'defaultContributionAmountKobo': 75000,
      'ownerId': 'owner-1',
      'createdBy': 'owner-1',
      'beneficiaryLimit': 2,
      'currency': 'NGN',
      'status': 'active',
      'balanceKobo': 425000,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });

    expect(decoded.pocket.description, 'Shared care savings');
    expect(decoded.pocket.frequency, FamilyContributionFrequency.weekly);
    expect(decoded.pocket.defaultContributionAmountKobo, 75000);
    expect(decoded.pocket.ownerId, 'owner-1');
    expect(decoded.pocket.balanceKobo, 425000);
  });

  test('removed Family Pocket membership preserves its audit timestamp', () {
    final removedAt = DateTime.utc(2026, 4, 5, 8);
    final document = FamilyMembershipDocument(
      FamilyMembership(
        id: 'user-2',
        pocketId: 'family-1',
        userId: 'user-2',
        invitationId: 'invite-1',
        name: 'Tayo Bello',
        role: FamilyRole.member,
        canContribute: true,
        isBeneficiary: false,
        status: FamilyMembershipStatus.removed,
        joinedAt: DateTime.utc(2026, 1, 1),
        removedAt: removedAt,
      ),
    );

    final encoded = document.toMap();
    final decoded = FamilyMembershipDocument.fromMap(
      'user-2',
      encoded,
    ).membership;

    expect(encoded, isNot(contains('email')));
    expect(decoded.status, FamilyMembershipStatus.removed);
    expect(decoded.removedAt?.toUtc(), removedAt);
  });

  test('Family invite keeps PII in its separate document', () {
    final createdAt = DateTime.utc(2026, 4, 5, 8);
    final document = FamilyInvitationDocument(
      FamilyInvitation(
        id: 'invite-1',
        pocketId: 'family-1',
        pocketName: 'Bello Family',
        inviteeName: 'Tola Bello',
        email: 'tola@example.com',
        inviterName: 'Tayo Bello',
        canContribute: true,
        isBeneficiary: true,
        beneficiarySlot: 1,
        status: FamilyInvitationStatus.pending,
        createdBy: 'admin-1',
        createdAt: createdAt,
        expiresAt: createdAt.add(const Duration(days: 7)),
      ),
    );

    final encoded = document.toMap();
    final decoded = FamilyInvitationDocument.fromMap(
      'invite-1',
      encoded,
    ).invitation;

    expect(encoded['email'], 'tola@example.com');
    expect(encoded['status'], 'pending');
    expect(decoded.canContribute, isTrue);
    expect(decoded.isBeneficiary, isTrue);
    expect(decoded.beneficiarySlot, 1);
  });

  test('Family contribution round-trips with integer kobo', () {
    final createdAt = DateTime.utc(2026, 4, 5, 8);
    final document = ContributionDocument(
      ContributionRecord(
        id: 'dev_family_user-1_0123456789abcdef',
        contributorUserId: 'user-1',
        familyPocketId: 'family-1',
        contributorName: 'Tayo Bello',
        amountKobo: 750050,
        currency: 'NGN',
        status: ContributionStatus.recorded,
        origin: ContributionOrigin.devSimulation,
        moneyMovement: false,
        idempotencyKey: '0123456789abcdef',
        createdAt: createdAt,
      ),
    );

    final encoded = document.toMap();
    final decoded = ContributionDocument.fromMap(
      'dev_family_user-1_0123456789abcdef',
      encoded,
    ).contribution;

    expect(encoded, containsPair('familyPocketId', 'family-1'));
    expect(encoded, isNot(contains('personalHealthPocketId')));
    expect(decoded.amountKobo, 750050);
    expect(decoded.contributorName, 'Tayo Bello');
  });

  test('server-owned wallet and ledger documents decode as typed models', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 15, 20));
    final wallet = WalletAccountDocument.fromMap('user-1', {
      'schemaVersion': 1,
      'userId': 'user-1',
      'currency': 'NGN',
      'availableBalanceKobo': 125050,
      'status': 'active',
      'version': 3,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    }).wallet;
    final entry = LedgerEntryDocument.fromMap('entry-1', {
      'schemaVersion': 1,
      'operationId': 'op-1',
      'userId': 'user-1',
      'walletId': 'user-1',
      'direction': 'debit',
      'amountKobo': 25050,
      'currency': 'NGN',
      'status': 'completed',
      'source': 'healthcare_payment',
      'providerReference': null,
      'familyPocketId': null,
      'reversesLedgerEntryId': null,
      'createdAt': timestamp,
    }).entry;
    final operation = FinancialOperationDocument.fromMap('op-1', {
      'schemaVersion': 1,
      'userId': 'user-1',
      'walletId': 'user-1',
      'direction': 'debit',
      'amountKobo': 25050,
      'currency': 'NGN',
      'status': 'completed',
      'source': 'healthcare_payment',
      'ledgerEntryId': 'entry-1',
      'failureCode': null,
      'providerReference': null,
      'familyPocketId': null,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    }).operation;

    expect(wallet.availableBalanceKobo, 125050);
    expect(wallet.status, WalletStatus.active);
    expect(entry.signedAmountKobo, -25050);
    expect(entry.source, FinancialSource.healthcarePayment);
    expect(operation.status, FinancialOperationStatus.completed);
    expect(operation.ledgerEntryId, 'entry-1');
  });

  test('server-owned funding transaction decodes receipt metadata', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 17, 8, 30));
    final transaction = FundingTransactionDocument.fromMap('pay-1', {
      'schemaVersion': 1,
      'userId': 'user-1',
      'paymentAttemptId': 'pay-1',
      'amountKobo': 250000,
      'currency': 'NGN',
      'status': 'completed',
      'provider': 'mock',
      'providerReference': 'mock_funding_000001',
      'ledgerOperationId': 'op-1',
      'failureCode': null,
      'transactionReference': 'pay-1',
      'receiptNumber': 'HPF-ABCDEF123456',
      'description': 'HealthPocket wallet funding',
      'channel': 'mock',
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'completedAt': timestamp,
    }).transaction;

    expect(transaction.status, FundingTransactionStatus.completed);
    expect(transaction.amountKobo, 250000);
    expect(transaction.hasReceipt, isTrue);
    expect(transaction.receiptNumber, 'HPF-ABCDEF123456');
  });

  test(
    'provider directory document decodes its canonical discovery fields',
    () {
      final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 18));
      final provider = CareProviderDocument.fromMap('clinic-1', {
        'schemaVersion': 1,
        'name': 'Community Clinic',
        'normalizedName': 'community clinic',
        'category': 'clinic',
        'partnerStatus': 'non_partner',
        'address': '10 Care Road',
        'state': 'Lagos',
        'city': 'Ikeja',
        'coordinates': {'latitude': 6.6018, 'longitude': 3.3515},
        'locationCell': ['g_386_733'],
        'contact': {
          'phone': '+2348000000000',
          'email': 'care@example.test',
          'website': 'https://example.test',
        },
        'openingInformation': 'Open daily',
        'logoUrl': 'https://example.test/logo.png',
        'imageUrls': ['https://example.test/provider.png'],
        'services': ['Consultation'],
        'searchPrefixes': ['c', 'cl'],
        'active': true,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'deactivatedAt': null,
      }).provider;

      expect(provider.type, CareProviderType.clinic);
      expect(provider.partnerStatus, CarePartnerStatus.nonPartner);
      expect(provider.locationCells, ['g_386_733']);
      expect(provider.coordinates?.isValid, isTrue);
      expect(provider.directionsUri.toString(), contains('maps/dir'));
      expect(provider.logoUrl?.scheme, 'https');
      expect(provider.isDemo, isFalse);
    },
  );
}
