import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/domain/app_pin.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecureValueStore implements SecureValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class SecureAppPinRepository implements AppPinRepository {
  SecureAppPinRepository({
    required this.storage,
    DateTime Function()? clock,
    Pbkdf2? algorithm,
  }) : _clock = clock ?? DateTime.now,
       _algorithm =
           algorithm ?? Pbkdf2.hmacSha256(iterations: 120000, bits: 256);

  static const _maximumAttempts = 5;
  static const _lockDuration = Duration(seconds: 30);
  static final _pinPattern = RegExp(r'^\d{6}$');

  final SecureValueStore storage;
  final DateTime Function() _clock;
  final Pbkdf2 _algorithm;

  @override
  Future<bool> hasPin(String userId) async =>
      await storage.read(_key(userId, 'hash')) != null &&
      await storage.read(_key(userId, 'salt')) != null;

  @override
  Future<void> setPin({required String userId, required String pin}) async {
    if (!_pinPattern.hasMatch(pin)) {
      throw const AuthFailure('Your HealthPocket PIN must contain six digits.');
    }
    final salt = randomBytes(16);
    final hash = await _derive(pin, salt);
    await storage.write(_key(userId, 'salt'), base64UrlEncode(salt));
    await storage.write(_key(userId, 'hash'), base64UrlEncode(hash));
    await storage.write(_key(userId, 'version'), 'pbkdf2-sha256-v1');
    await _clearRateLimit(userId);
  }

  @override
  Future<PinVerificationResult> verifyPin({
    required String userId,
    required String pin,
  }) async {
    final now = _clock();
    final lockedUntil = DateTime.tryParse(
      await storage.read(_key(userId, 'lockedUntil')) ?? '',
    );
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      return PinVerificationResult.locked(lockedUntil);
    }

    final encodedSalt = await storage.read(_key(userId, 'salt'));
    final encodedHash = await storage.read(_key(userId, 'hash'));
    if (encodedSalt == null || encodedHash == null) {
      throw const AuthFailure('No local PIN exists for this account.');
    }

    final candidate = await _derive(pin, base64Url.decode(encodedSalt));
    final expected = base64Url.decode(encodedHash);
    if (constantTimeBytesEquality.equals(candidate, expected)) {
      await _clearRateLimit(userId);
      return const PinVerificationResult.valid();
    }

    final previousAttempts = int.tryParse(
      await storage.read(_key(userId, 'failedAttempts')) ?? '',
    );
    final attempts = (previousAttempts ?? 0) + 1;
    if (attempts >= _maximumAttempts) {
      final nextAttemptAt = now.add(_lockDuration);
      await storage.write(
        _key(userId, 'lockedUntil'),
        nextAttemptAt.toUtc().toIso8601String(),
      );
      await storage.write(_key(userId, 'failedAttempts'), '0');
      return PinVerificationResult.locked(nextAttemptAt);
    }
    await storage.write(_key(userId, 'failedAttempts'), '$attempts');
    return PinVerificationResult.invalid(_maximumAttempts - attempts);
  }

  @override
  Future<void> clearPin(String userId) async {
    for (final suffix in const [
      'salt',
      'hash',
      'version',
      'failedAttempts',
      'lockedUntil',
    ]) {
      await storage.delete(_key(userId, suffix));
    }
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    final key = await _algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<void> _clearRateLimit(String userId) async {
    await storage.delete(_key(userId, 'failedAttempts'));
    await storage.delete(_key(userId, 'lockedUntil'));
  }

  String _key(String userId, String suffix) => 'hp.pin.$userId.$suffix';
}
