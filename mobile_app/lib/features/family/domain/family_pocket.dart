enum FamilyRole { admin, contributor, beneficiary }

enum FamilyInvitationStatus { pending, accepted, removed }

enum FamilyPocketStatus { active, archived }

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
    required this.members,
  });

  final String id;
  final String name;
  final String beneficiary;
  final List<FamilyMember> members;

  FamilyPocket copyWith({List<FamilyMember>? members}) {
    return FamilyPocket(
      id: id,
      name: name,
      beneficiary: beneficiary,
      members: members ?? this.members,
    );
  }
}

class FamilyMembership {
  const FamilyMembership({
    required this.id,
    required this.pocketId,
    required this.name,
    required this.email,
    required this.role,
    required this.invitationStatus,
    this.userId,
    this.joinedAt,
    this.removedAt,
  });

  final String id;
  final String pocketId;
  final String? userId;
  final String name;
  final String email;
  final FamilyRole role;
  final FamilyInvitationStatus invitationStatus;
  final DateTime? joinedAt;
  final DateTime? removedAt;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.pocketId,
    required this.name,
    required this.email,
    required this.role,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String pocketId;
  final String name;
  final String email;
  final FamilyRole role;
  final String createdBy;
  final DateTime? createdAt;
}
