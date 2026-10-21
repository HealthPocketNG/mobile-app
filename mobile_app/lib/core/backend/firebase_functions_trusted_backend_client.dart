import 'package:cloud_functions/cloud_functions.dart';
import 'package:healthpocket/core/backend/trusted_backend_client.dart';
import 'package:healthpocket/core/errors/backend_failure.dart';
import 'package:healthpocket/core/logging/backend_logger.dart';

class FirebaseFunctionsTrustedBackendClient implements TrustedBackendClient {
  FirebaseFunctionsTrustedBackendClient(
    FirebaseFunctions functions, {
    BackendLogger? logger,
  }) : _logger = logger ?? BackendLogger.instance,
       _callable = functions.httpsCallable(
         'trustedBackend',
         options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
       );

  final HttpsCallable _callable;
  final BackendLogger _logger;

  @override
  Future<Map<String, dynamic>> call(
    TrustedBackendAction action, {
    Map<String, Object?> payload = const {},
  }) => _logger.trace<Map<String, dynamic>>(
    repository: 'functions',
    operation: action.wireName,
    entity: 'trusted_backend',
    action: () async {
      try {
        final result = await _callable.call<Object?>(<String, Object?>{
          'action': action.wireName,
          'payload': payload,
        });
        final data = result.data;
        if (data is! Map) {
          throw BackendFailure.fromCode(BackendFailureCodes.internal);
        }
        final normalized = <String, dynamic>{};
        for (final entry in data.entries) {
          if (entry.key is! String) {
            throw BackendFailure.fromCode(BackendFailureCodes.internal);
          }
          normalized[entry.key as String] = entry.value;
        }
        return Map.unmodifiable(normalized);
      } on FirebaseFunctionsException catch (error) {
        throw backendFailureFromCallable(
          transportCode: error.code,
          details: error.details,
        );
      }
    },
  );
}
