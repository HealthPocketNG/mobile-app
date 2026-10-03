import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/data/backend_ids.dart';
import 'package:healthpocket/core/data/firestore/firestore_repositories.dart';
import 'package:healthpocket/core/logging/backend_logger.dart';

void main() {
  test('Firestore repositories compile against the shared conventions', () {
    const repositoryTypes = <Type>[
      FirestoreProfileRepository,
      FirestoreSavingsRepository,
      FirestoreContributionRepository,
      FirestoreFamilyPocketRepository,
    ];
    expect(repositoryTypes, hasLength(4));
  });

  group('BackendIds', () {
    test('builds deterministic owner-scoped IDs', () {
      expect(BackendIds.personalPocket('user_1'), 'personal-user_1');
      expect(BackendIds.savingsPlan('user_1'), 'personal-plan-user_1');
      expect(
        BackendIds.personalContribution('user_1', '0123456789abcdef'),
        'dev_user_1_0123456789abcdef',
      );
      expect(
        BackendIds.familyContribution('user_1', '0123456789abcdef'),
        'dev_family_user_1_0123456789abcdef',
      );
    });

    test('generates unpredictable path-safe application IDs', () {
      final first = BackendIds.familyPocket('user_1');
      final second = BackendIds.familyPocket('user_1');
      final invitation = BackendIds.invitation('user_1');

      expect(first, isNot(second));
      expect(BackendIds.isFamilyPocketForUser(first, 'user_1'), isTrue);
      expect(BackendIds.isInvitationForUser(invitation, 'user_1'), isTrue);
      expect(BackendIds.isSafe(first), isTrue);
      expect(BackendIds.isSafe(invitation), isTrue);
    });

    test('rejects unsafe IDs and malformed request keys', () {
      expect(() => BackendIds.requireSafe('users/user_1'), throwsArgumentError);
      expect(() => BackendIds.requireSafe('user 1'), throwsArgumentError);
      expect(
        () => BackendIds.requireRequestKey('too-short'),
        throwsArgumentError,
      );
    });
  });

  group('BackendLogger', () {
    test(
      'emits structured lifecycle events without sensitive metadata',
      () async {
        final entries = <BackendLogEntry>[];
        final logger = BackendLogger(
          sink: entries.add,
          clock: () => DateTime.utc(2026, 10, 2),
        );

        logger.info(
          'backend.custom',
          fields: {
            'repository': 'profile',
            'recordCount': 2,
            'email': 'person@example.com',
            'operation': 'person@example.com',
            'entity': 'Bearer-secret',
            'pin': '123456',
          },
        );
        await logger.trace<void>(
          repository: 'savings',
          operation: 'save',
          entity: 'savings_plan',
          action: () async {},
        );

        expect(entries, hasLength(3));
        expect(entries.first.fields, {
          'repository': 'profile',
          'recordCount': 2,
        });
        expect(entries[1].event, 'backend.operation.started');
        expect(entries[2].fields['outcome'], 'success');
        final serialized = entries
            .expand(
              (entry) => [
                entry.event,
                ...entry.fields.keys,
                ...entry.fields.values.map((value) => value.toString()),
              ],
            )
            .join(' ');
        expect(serialized, isNot(contains('person@example.com')));
        expect(serialized, isNot(contains('123456')));
        expect(serialized.toLowerCase(), isNot(contains('bearer-secret')));
      },
    );

    test('records only an error type before rethrowing', () async {
      final entries = <BackendLogEntry>[];
      final logger = BackendLogger(sink: entries.add);

      await expectLater(
        logger.trace<void>(
          repository: 'profile',
          operation: 'save',
          entity: 'user_profile',
          action: () async => throw StateError('private payload'),
        ),
        throwsStateError,
      );

      expect(entries.last.level, BackendLogLevel.error);
      expect(entries.last.fields['outcome'], 'failure');
      expect(entries.last.fields['errorType'], 'StateError');
      expect(
        entries.last.toJson().toString(),
        isNot(contains('private payload')),
      );
    });
  });
}
