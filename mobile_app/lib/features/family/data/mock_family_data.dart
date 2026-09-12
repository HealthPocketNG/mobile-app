import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';

abstract final class MockFamilyData {
  static const pockets = [
    FamilyPocket(
      id: 'adebayo-family-care',
      name: 'Adebayo Family Care',
      beneficiary: 'The Adebayo family',
      members: [
        FamilyMember(
          id: 'current-user',
          name: 'Samson Adebayo',
          email: 'samson@example.com',
          role: FamilyRole.admin,
        ),
        FamilyMember(
          id: 'grace',
          name: 'Grace Adebayo',
          email: 'grace@example.com',
          role: FamilyRole.contributor,
        ),
        FamilyMember(
          id: 'mama',
          name: 'Mama Adebayo',
          email: 'mama@example.com',
          role: FamilyRole.beneficiary,
        ),
      ],
    ),
  ];

  static final contributions = [
    ContributionRecord(
      id: 'family-contribution-1',
      contributorUserId: 'current-user',
      familyPocketId: 'adebayo-family-care',
      contributorName: 'Samson',
      amountKobo: 1500000,
      currency: 'NGN',
      status: ContributionStatus.recorded,
      origin: ContributionOrigin.devSimulation,
      moneyMovement: false,
      idempotencyKey: 'mockfamilyrecord01',
      createdAt: DateTime.now(),
    ),
    ContributionRecord(
      id: 'family-contribution-2',
      contributorUserId: 'grace',
      familyPocketId: 'adebayo-family-care',
      contributorName: 'Grace',
      amountKobo: 2000000,
      currency: 'NGN',
      status: ContributionStatus.recorded,
      origin: ContributionOrigin.devSimulation,
      moneyMovement: false,
      idempotencyKey: 'mockfamilyrecord02',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
}
