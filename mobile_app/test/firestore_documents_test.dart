import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/data/firestore/firestore_documents.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

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
      updatedAt: updatedAt,
    ).toMap();
    final decoded = UserProfileDocument.fromMap('user-1', encoded);

    expect(decoded.userId, 'user-1');
    expect(decoded.profile.fullName, profile.fullName);
    expect(decoded.profile.dateOfBirth?.toUtc(), profile.dateOfBirth);
    expect(decoded.profile.demoKycComplete, isTrue);
    expect(decoded.notifications.healthReminders, isFalse);
    expect(decoded.kycStatus, KycStatus.demoComplete);
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
        contributionAmount: 5000,
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
    expect(decoded.plan.frequency, SavingsFrequency.weekly);
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
}
