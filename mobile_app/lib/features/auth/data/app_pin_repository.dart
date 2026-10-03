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
  static const _credentialVersion = 'pbkdf2-sha256-v2';
  static const _legacyCredentialVersion = 'pbkdf2-sha256-v1';
  static const _lockDurations = <Duration>[
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];
  static final _pinPattern = RegExp(r'^\d{6}$');

  final SecureValueStore storage;
  final DateTime Function() _clock;
  final Pbkdf2 _algorithm;

  @override
  Future<bool> hasPin(String userId) async =>
      await _readCredential(userId) != null;

  @override
  Future<void> setPin({required String userId, required String pin}) async {
    if (!_pinPattern.hasMatch(pin)) {
      throw const AuthFailure('Your HealthPocket PIN must contain six digits.');
    }
    final salt = randomBytes(16);
    final hash = await _derive(pin, salt);
    await storage.write(
      _key(userId, 'record'),
      jsonEncode({
        'version': _credentialVersion,
        'salt': base64UrlEncode(salt),
        'hash': base64UrlEncode(hash),
      }),
    );
    await _deleteLegacyCredential(userId);
    await _clearRateLimit(userId);
  }

  @override
  Future<PinVerificationResult> verifyPin({
    required String userId,
    required String pin,
  }) async {
    final now = _clock();
    final encodedLockedUntil = await storage.read(_key(userId, 'lockedUntil'));
    final lockedUntil = DateTime.tryParse(encodedLockedUntil ?? '');
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      return PinVerificationResult.locked(lockedUntil);
    }
    if (encodedLockedUntil != null) {
      await storage.delete(_key(userId, 'lockedUntil'));
    }

    final credential = await _readCredential(userId);
    if (credential == null) {
      throw const AuthFailure('No local PIN exists for this account.');
    }

    if (_pinPattern.hasMatch(pin)) {
      final candidate = await _derive(pin, credential.salt);
      if (constantTimeBytesEquality.equals(candidate, credential.hash)) {
        await _clearRateLimit(userId);
        return const PinVerificationResult.valid();
      }
    }
    return _recordFailure(userId, now);
  }

  Future<PinVerificationResult> _recordFailure(
    String userId,
    DateTime now,
  ) async {
    final previousAttempts = int.tryParse(
      await storage.read(_key(userId, 'failedAttempts')) ?? '',
    );
    final attempts =
        (previousAttempts ?? 0).clamp(0, _maximumAttempts - 1).toInt() + 1;
    if (attempts < _maximumAttempts) {
      await storage.write(_key(userId, 'failedAttempts'), '$attempts');
      return PinVerificationResult.invalid(_maximumAttempts - attempts);
    }

    final previousLevel = int.tryParse(
      await storage.read(_key(userId, 'lockoutLevel')) ?? '',
    );
    final level = (previousLevel ?? 0)
        .clamp(0, _lockDurations.length - 1)
        .toInt();
    final nextAttemptAt = now.add(_lockDurations[level]);
    await storage.write(
      _key(userId, 'lockedUntil'),
      nextAttemptAt.toUtc().toIso8601String(),
    );
    await storage.write(
      _key(userId, 'lockoutLevel'),
      '${(level + 1).clamp(0, _lockDurations.length - 1)}',
    );
    await storage.delete(_key(userId, 'failedAttempts'));
    return PinVerificationResult.locked(nextAttemptAt);
  }

  Future<_PinCredential?> _readCredential(String userId) async {
    final encodedRecord = await storage.read(_key(userId, 'record'));
    if (encodedRecord != null) {
      try {
        final decoded = jsonDecode(encodedRecord);
        if (decoded is! Map<String, dynamic> ||
            decoded['version'] != _credentialVersion ||
            decoded['salt'] is! String ||
            decoded['hash'] is! String) {
          throw const FormatException('Unsupported local PIN record.');
        }
        final salt = base64Url.decode(decoded['salt'] as String);
        final hash = base64Url.decode(decoded['hash'] as String);
        if (salt.length != 16 || hash.length != 32) {
          throw const FormatException('Invalid local PIN record.');
        }
        return _PinCredential(salt: salt, hash: hash);
      } on FormatException {
        await clearPin(userId);
        return null;
      }
    }

    final legacyVersion = await storage.read(_key(userId, 'version'));
    final encodedSalt = await storage.read(_key(userId, 'salt'));
    final encodedHash = await storage.read(_key(userId, 'hash'));
    if (legacyVersion == null && encodedSalt == null && encodedHash == null) {
      return null;
    }
    try {
      if (legacyVersion != _legacyCredentialVersion ||
          encodedSalt == null ||
          encodedHash == null) {
        throw const FormatException('Incomplete legacy PIN record.');
      }
      final salt = base64Url.decode(encodedSalt);
      final hash = base64Url.decode(encodedHash);
      if (salt.length != 16 || hash.length != 32) {
        throw const FormatException('Invalid legacy PIN record.');
      }
      await storage.write(
        _key(userId, 'record'),
        jsonEncode({
          'version': _credentialVersion,
          'salt': encodedSalt,
          'hash': encodedHash,
        }),
      );
      await _deleteLegacyCredential(userId);
      return _PinCredential(salt: salt, hash: hash);
    } on FormatException {
      await clearPin(userId);
      return null;
    }
  }

  @override
  Future<void> clearPin(String userId) async {
    for (final suffix in const [
      'salt',
      'hash',
      'version',
      'record',
      'failedAttempts',
      'lockedUntil',
      'lockoutLevel',
    ]) {
      await storage.delete(_key(userId, suffix));
    }
  }

  Future<void> _deleteLegacyCredential(String userId) async {
    for (final suffix in const ['salt', 'hash', 'version']) {
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
    await storage.delete(_key(userId, 'lockoutLevel'));
  }

  String _key(String userId, String suffix) => 'hp.pin.$userId.$suffix';
}

class _PinCredential {
  const _PinCredential({required this.salt, required this.hash});

  final List<int> salt;
  final List<int> hash;
}
