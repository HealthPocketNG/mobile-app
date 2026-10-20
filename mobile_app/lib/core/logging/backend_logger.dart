import 'dart:convert';
import 'dart:developer' as developer;

import 'package:healthpocket/core/errors/backend_failure.dart';

enum BackendLogLevel { info, warning, error }

class BackendLogEntry {
  const BackendLogEntry({
    required this.timestamp,
    required this.level,
    required this.event,
    required this.fields,
  });

  final DateTime timestamp;
  final BackendLogLevel level;
  final String event;
  final Map<String, Object> fields;

  Map<String, Object> toJson() => <String, Object>{
    'timestamp': timestamp.toUtc().toIso8601String(),
    'level': level.name,
    'event': event,
    ...fields,
  };
}

typedef BackendLogSink = void Function(BackendLogEntry entry);

/// Privacy-safe operational logging at the repository/backend boundary.
///
/// Only a small metadata vocabulary is accepted. User IDs, document IDs,
/// names, email addresses, PINs, tokens and request payloads are deliberately
/// excluded; rejected values are never emitted, even under an allowed key.
class BackendLogger {
  BackendLogger({BackendLogSink? sink, DateTime Function()? clock})
    : _sink = sink ?? _developerSink,
      _clock = clock ?? DateTime.now;

  static final BackendLogger instance = BackendLogger();

  static const Set<String> _allowedFields = <String>{
    'repository',
    'operation',
    'entity',
    'outcome',
    'errorType',
    'recordCount',
    'isRetry',
  };

  final BackendLogSink _sink;
  final DateTime Function() _clock;

  void info(String event, {Map<String, Object?> fields = const {}}) =>
      _write(BackendLogLevel.info, event, fields);

  void warning(String event, {Map<String, Object?> fields = const {}}) =>
      _write(BackendLogLevel.warning, event, fields);

  void error(String event, {Map<String, Object?> fields = const {}}) =>
      _write(BackendLogLevel.error, event, fields);

  Future<T> trace<T>({
    required String repository,
    required String operation,
    required String entity,
    required Future<T> Function() action,
  }) async {
    final common = <String, Object?>{
      'repository': repository,
      'operation': operation,
      'entity': entity,
    };
    info(
      'backend.operation.started',
      fields: {...common, 'outcome': 'started'},
    );
    try {
      final result = await action();
      info(
        'backend.operation.completed',
        fields: {...common, 'outcome': 'success'},
      );
      return result;
    } catch (error) {
      this.error(
        'backend.operation.failed',
        fields: {
          ...common,
          'outcome': 'failure',
          'errorType': error.runtimeType.toString(),
        },
      );
      throw mapBackendFailure(error);
    }
  }

  void _write(
    BackendLogLevel level,
    String event,
    Map<String, Object?> fields,
  ) {
    final safeEvent = _safeLabel(event, fallback: 'backend.event.invalid');
    final safeFields = <String, Object>{};
    for (final entry in fields.entries) {
      if (!_allowedFields.contains(entry.key)) continue;
      final value = entry.value;
      if (value is bool) {
        safeFields[entry.key] = value;
      } else if (value is int) {
        safeFields[entry.key] = value;
      } else if (value is String && _isSafeValue(value)) {
        safeFields[entry.key] = value;
      }
    }
    _sink(
      BackendLogEntry(
        timestamp: _clock(),
        level: level,
        event: safeEvent,
        fields: Map.unmodifiable(safeFields),
      ),
    );
  }

  static bool _isSafeValue(String value) {
    if (value.isEmpty || value.length > 64) return false;
    if (value.contains('@') || value.contains('://')) return false;
    if (RegExp(
      r'(bearer|token|secret|password|pin)',
      caseSensitive: false,
    ).hasMatch(value)) {
      return false;
    }
    return RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,63}$').hasMatch(value);
  }

  static String _safeLabel(String value, {required String fallback}) =>
      _isSafeValue(value) ? value : fallback;

  static void _developerSink(BackendLogEntry entry) {
    developer.log(
      jsonEncode(entry.toJson()),
      name: 'healthpocket.backend',
      level: switch (entry.level) {
        BackendLogLevel.info => 800,
        BackendLogLevel.warning => 900,
        BackendLogLevel.error => 1000,
      },
    );
  }
}
