import 'package:cloud_firestore/cloud_firestore.dart';

String firestoreString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is String) return value;
  throw FormatException('Expected "$field" to be a string.');
}

String? firestoreNullableString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected "$field" to be a string or null.');
}

int firestoreInt(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is int) return value;
  throw FormatException('Expected "$field" to be an integer.');
}

bool firestoreBool(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is bool) return value;
  throw FormatException('Expected "$field" to be a boolean.');
}

DateTime firestoreDateTime(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('Expected "$field" to be a timestamp.');
}

DateTime? firestoreNullableDateTime(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('Expected "$field" to be a timestamp or null.');
}

Map<String, Object?> firestoreObjectMap(
  Map<String, dynamic> data,
  String field,
) {
  final value = data[field];
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('Expected "$field" to be a map.');
}

T firestoreEnum<T extends Enum>(
  Map<String, dynamic> data,
  String field,
  List<T> values,
) {
  final encoded = firestoreString(data, field);
  return values.firstWhere(
    (value) => value.name == encoded,
    orElse: () => throw FormatException('Unknown "$field" value "$encoded".'),
  );
}

Timestamp firestoreTimestamp(DateTime value) => Timestamp.fromDate(value);
