enum FamilyRole { admin, contributor, beneficiary }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isPending = false,
  });

  final String id;
  final String name;
  final String email;
  final FamilyRole role;
  final bool isPending;
}

class FamilyPocket {
  const FamilyPocket({
    required this.id,
    required this.name,
    required this.beneficiary,
    required this.goalAmount,
    required this.currentAmount,
    required this.members,
  });

  final String id;
  final String name;
  final String beneficiary;
  final int goalAmount;
  final int currentAmount;
  final List<FamilyMember> members;

  double get progress => goalAmount == 0 ? 0 : currentAmount / goalAmount;

  FamilyPocket copyWith({int? currentAmount, List<FamilyMember>? members}) {
    return FamilyPocket(
      id: id,
      name: name,
      beneficiary: beneficiary,
      goalAmount: goalAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      members: members ?? this.members,
    );
  }
}

class FamilyContribution {
  const FamilyContribution({
    required this.id,
    required this.pocketId,
    required this.memberName,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String pocketId;
  final String memberName;
  final int amount;
  final DateTime createdAt;
}
