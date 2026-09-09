enum PersonalHealthPocketStatus { active, restricted, closed }

class PersonalHealthPocket {
  const PersonalHealthPocket({
    required this.id,
    required this.userId,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String currency;
  final PersonalHealthPocketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
