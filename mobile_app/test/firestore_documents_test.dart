import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/data/firestore/firestore_documents.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

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
        amount: 5000,
        currency: 'NGN',
        status: ContributionStatus.completed,
        source: ContributionSource.manual,
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
    expect(decoded.amount, 5000);
    expect(decoded.createdAt.toUtc(), createdAt);
  });

  test('removed Family Pocket membership preserves its audit timestamp', () {
    final removedAt = DateTime.utc(2026, 4, 5, 8);
    final document = FamilyMembershipDocument(
      FamilyMembership(
        id: 'user-2',
        pocketId: 'family-1',
        userId: 'user-2',
        name: 'Tayo Bello',
        email: 'tayo@example.com',
        role: FamilyRole.contributor,
        invitationStatus: FamilyInvitationStatus.removed,
        joinedAt: DateTime.utc(2026, 1, 1),
        removedAt: removedAt,
      ),
    );

    final decoded = FamilyMembershipDocument.fromMap(
      'user-2',
      document.toMap(),
    ).membership;

    expect(decoded.invitationStatus, FamilyInvitationStatus.removed);
    expect(decoded.removedAt?.toUtc(), removedAt);
  });
}
