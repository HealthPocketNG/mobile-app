import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

void main() {
  late MemorySecureValueStore storage;
  late SecureAppPinRepository repository;
  var now = DateTime.utc(2027, 1, 1);

  setUp(() {
    storage = MemorySecureValueStore();
    repository = SecureAppPinRepository(
      storage: storage,
      clock: () => now,
      algorithm: Pbkdf2.hmacSha256(iterations: 10, bits: 256),
    );
  });

  test('stores only a salted PIN hash and verifies the correct PIN', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');

    expect(await repository.hasPin('user-1'), isTrue);
    expect(await storage.read('hp.pin.user-1.hash'), isNot('482913'));
    expect(await storage.read('hp.pin.user-1.salt'), isNotNull);
    expect(await storage.read('hp.pin.user-1.version'), 'pbkdf2-sha256-v1');
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

  test(
    'locks after five failed attempts and allows retry after cooldown',
    () async {
      await repository.setPin(userId: 'user-1', pin: '482913');

      for (var attempt = 0; attempt < 4; attempt++) {
        final result = await repository.verifyPin(
          userId: 'user-1',
          pin: '000000',
        );
        expect(result.isLocked, isFalse);
      }
      final locked = await repository.verifyPin(
        userId: 'user-1',
        pin: '000000',
      );
      expect(locked.isLocked, isTrue);

      now = now.add(const Duration(seconds: 31));
      final valid = await repository.verifyPin(userId: 'user-1', pin: '482913');
      expect(valid.isValid, isTrue);
    },
  );

  test('clears all local PIN material during recovery', () async {
    await repository.setPin(userId: 'user-1', pin: '482913');
    await repository.clearPin('user-1');

    expect(await repository.hasPin('user-1'), isFalse);
    expect(await storage.read('hp.pin.user-1.hash'), isNull);
    expect(await storage.read('hp.pin.user-1.salt'), isNull);
  });
}
