class ActivityRecord {
  ActivityRecord({
    required this.id,
    required this.userId,
    required this.activityType,
    required Map<String, Object?> metadata,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.createdAt,
    this.familyPocketId,
  }) : metadata = Map.unmodifiable(metadata);

  final String id;
  final String userId;
  final String activityType;
  final Map<String, Object?> metadata;
  final String relatedEntityType;
  final String relatedEntityId;
  final String? familyPocketId;
  final DateTime createdAt;
}
