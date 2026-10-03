import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

void main() {
  late MemorySecureValueStore storage;
  late SecureAppPinRepository repository;
  late DateTime now;

  Pbkdf2 testAlgorithm() => Pbkdf2.hmacSha256(iterations: 10, bits: 256);

  SecureAppPinRepository buildRepository() => SecureAppPinRepository(
    storage: storage,
    clock: () => now,
    algorithm: testAlgorithm(),
  );

  setUp(() {
    now = DateTime.utc(2027, 1, 1);
    storage = MemorySecureValueStore();
    repository = buildRepository();
  });

  test('stores only a versioned salted hash and verifies the PIN', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');

    final encodedRecord = await storage.read('hp.pin.user-1.record');
    final record = jsonDecode(encodedRecord!) as Map<String, dynamic>;
    expect(await repository.hasPin('user-1'), isTrue);
    expect(encodedRecord, isNot(contains('482913')));
    expect(record['version'], 'pbkdf2-sha256-v2');
    expect(record['salt'], isNotEmpty);
    expect(record['hash'], isNotEmpty);
    expect(await storage.read('hp.pin.user-1.hash'), isNull);
    expect(await storage.read('hp.pin.user-1.salt'), isNull);
    expect(
      (await repository.verifyPin(userId: 'user-1', pin: '482913')).isValid,
      isTrue,
    );
  });

  test('rejects non-six-digit PINs', () async {
    expect(
      repository.setPin(userId: 'user-1', pin: '12345'),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('lockout survives repository restart and expires', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');

    for (var attempt = 0; attempt < 5; attempt++) {
      await repository.verifyPin(userId: 'user-1', pin: '000000');
    }
    repository = buildRepository();

    final stillLocked = await repository.verifyPin(
      userId: 'user-1',
      pin: '482913',
    );
    expect(stillLocked.isLocked, isTrue);

    now = now.add(const Duration(seconds: 31));
    final lockedAfterTypicalRebuild = await repository.verifyPin(
      userId: 'user-1',
      pin: '482913',
    );
    expect(lockedAfterTypicalRebuild.isLocked, isTrue);

    now = now.add(const Duration(minutes: 1, seconds: 30));
    final valid = await repository.verifyPin(userId: 'user-1', pin: '482913');
    expect(valid.isValid, isTrue);
  });

  test('repeated lockouts progressively increase the cooldown', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');

    for (var attempt = 0; attempt < 5; attempt++) {
      await repository.verifyPin(userId: 'user-1', pin: '000000');
    }
    now = now.add(const Duration(minutes: 2, seconds: 1));
    for (var attempt = 0; attempt < 5; attempt++) {
      await repository.verifyPin(userId: 'user-1', pin: '000000');
    }

    final lockedUntil = DateTime.parse(
      (await storage.read('hp.pin.user-1.lockedUntil'))!,
    );
    expect(lockedUntil.difference(now), const Duration(minutes: 5));
  });

  test('malformed verification attempts consume the retry allowance', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');

    final result = await repository.verifyPin(
      userId: 'user-1',
      pin: 'not-a-pin',
    );

    expect(result.isValid, isFalse);
    expect(result.remainingAttempts, 4);
  });

  test(
    'migrates a valid legacy credential without retaining old keys',
    () async {
      final salt = List<int>.generate(16, (index) => index);
      final key = await testAlgorithm().deriveKeyFromPassword(
        password: '482913',
        nonce: salt,
      );
      final hash = await key.extractBytes();
      await storage.write('hp.pin.user-1.version', 'pbkdf2-sha256-v1');
      await storage.write('hp.pin.user-1.salt', base64UrlEncode(salt));
      await storage.write('hp.pin.user-1.hash', base64UrlEncode(hash));

      expect(await repository.hasPin('user-1'), isTrue);
      expect(await storage.read('hp.pin.user-1.record'), isNotNull);
      expect(await storage.read('hp.pin.user-1.version'), isNull);
      expect(await storage.read('hp.pin.user-1.salt'), isNull);
      expect(await storage.read('hp.pin.user-1.hash'), isNull);
      expect(
        (await repository.verifyPin(userId: 'user-1', pin: '482913')).isValid,
        isTrue,
      );
    },
  );

  test(
    'removes corrupt local credentials instead of bypassing unlock',
    () async {
      await storage.write(
        'hp.pin.user-1.record',
        '{"version":"unknown","salt":"bad","hash":"bad"}',
      );

      expect(await repository.hasPin('user-1'), isFalse);
      expect(await storage.read('hp.pin.user-1.record'), isNull);
      expect(
        repository.verifyPin(userId: 'user-1', pin: '482913'),
        throwsA(isA<AuthFailure>()),
      );
    },
  );

  test('clears credentials and retry state during recovery', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');
    await repository.verifyPin(userId: 'user-1', pin: '000000');
    await repository.clearPin('user-1');

    for (final suffix in [
      'record',
      'hash',
      'salt',
      'version',
      'failedAttempts',
      'lockedUntil',
      'lockoutLevel',
    ]) {
      expect(await storage.read('hp.pin.user-1.$suffix'), isNull);
    }
  });

  test('a fresh secure store after reinstall has no local PIN', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');

    storage = MemorySecureValueStore();
    repository = buildRepository();

    expect(await repository.hasPin('user-1'), isFalse);
  });
}
