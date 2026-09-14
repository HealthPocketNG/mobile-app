enum FamilyRole { admin, member }

enum FamilyMembershipStatus { accepted, removed }

enum FamilyInvitationStatus { pending, accepted, declined, cancelled, expired }

enum FamilyPocketStatus { active, archived }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.canContribute,
    required this.isBeneficiary,
    this.beneficiarySlot,
  });

  final String id;
  final String name;
  final FamilyRole role;
  final bool canContribute;
  final bool isBeneficiary;
  final int? beneficiarySlot;
}

class FamilyPocket {
  const FamilyPocket({
    required this.id,
    required this.name,
    required this.members,
    this.invitations = const [],
    this.beneficiaryLimit = 2,
  });

  final String id;
  final String name;
  final List<FamilyMember> members;
  final List<FamilyInvitation> invitations;
  final int beneficiaryLimit;

  int get reservedBeneficiaryCount =>
      members.where((member) => member.isBeneficiary).length +
      invitations.where((invitation) {
        return invitation.isBeneficiary &&
            invitation.status == FamilyInvitationStatus.pending;
      }).length;

  FamilyPocket copyWith({
    List<FamilyMember>? members,
    List<FamilyInvitation>? invitations,
  }) {
    return FamilyPocket(
      id: id,
      name: name,
      members: members ?? this.members,
      invitations: invitations ?? this.invitations,
      beneficiaryLimit: beneficiaryLimit,
    );
  }
}

class FamilyMembership {
  const FamilyMembership({
    required this.id,
    required this.pocketId,
    required this.name,
    required this.role,
    required this.canContribute,
    required this.isBeneficiary,
    required this.status,
    this.userId,
    this.invitationId,
    this.beneficiarySlot,
    this.joinedAt,
    this.removedAt,
  });

  final String id;
  final String pocketId;
  final String? userId;
  final String? invitationId;
  final String name;
  final FamilyRole role;
  final bool canContribute;
  final bool isBeneficiary;
  final FamilyMembershipStatus status;
  final int? beneficiarySlot;
  final DateTime? joinedAt;
  final DateTime? removedAt;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.pocketId,
    required this.pocketName,
    required this.inviteeName,
    required this.email,
    required this.inviterName,
    required this.canContribute,
    required this.isBeneficiary,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.beneficiarySlot,
    this.respondedBy,
    this.respondedAt,
  });

  final String id;
  final String pocketId;
  final String pocketName;
  final String inviteeName;
  final String email;
  final String inviterName;
  final bool canContribute;
  final bool isBeneficiary;
  final int? beneficiarySlot;
  final FamilyInvitationStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime expiresAt;
  final String? respondedBy;
  final DateTime? respondedAt;

  FamilyInvitationStatus get effectiveStatus =>
      status == FamilyInvitationStatus.pending &&
          expiresAt.isBefore(DateTime.now())
      ? FamilyInvitationStatus.expired
      : status;

  FamilyInvitation copyWith({
    FamilyInvitationStatus? status,
    String? respondedBy,
    DateTime? respondedAt,
  }) => FamilyInvitation(
    id: id,
    pocketId: pocketId,
    pocketName: pocketName,
    inviteeName: inviteeName,
    email: email,
    inviterName: inviterName,
    canContribute: canContribute,
    isBeneficiary: isBeneficiary,
    beneficiarySlot: beneficiarySlot,
    status: status ?? this.status,
    createdBy: createdBy,
    createdAt: createdAt,
    expiresAt: expiresAt,
    respondedBy: respondedBy ?? this.respondedBy,
    respondedAt: respondedAt ?? this.respondedAt,
  );
}
