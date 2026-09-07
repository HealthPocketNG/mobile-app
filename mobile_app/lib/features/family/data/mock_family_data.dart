import 'package:healthpocket/features/family/domain/family_pocket.dart';

abstract final class MockFamilyData {
  static const pockets = [
    FamilyPocket(
      id: 'adebayo-family-care',
      name: 'Adebayo Family Care',
      beneficiary: 'The Adebayo family',
      goalAmount: 200000,
      currentAmount: 35000,
      members: [
        FamilyMember(
          id: 'samson',
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
    FamilyContribution(
      id: 'family-contribution-1',
      pocketId: 'adebayo-family-care',
      memberName: 'Samson',
      amount: 15000,
      createdAt: DateTime.now(),
    ),
    FamilyContribution(
      id: 'family-contribution-2',
      pocketId: 'adebayo-family-care',
      memberName: 'Grace',
      amount: 20000,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
}
