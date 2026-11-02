import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricUnlockService {
  BiometricUnlockService({
    LocalAuthentication? authenticator,
    FlutterSecureStorage? storage,
  }) : _authenticator = authenticator ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _authenticator;
  final FlutterSecureStorage _storage;

  Future<bool> isAvailable() async {
    try {
      return (await _authenticator.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled(String uid) async {
    try {
      return await _storage.read(key: 'hp.biometric.$uid') == 'enabled';
    } catch (_) {
      return false;
    }
  }

  Future<bool> shouldOffer(String uid) async {
    try {
      return await _storage.read(key: 'hp.biometric.$uid') == null &&
          await isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<bool> enable(String uid) async {
    if (!await isAvailable()) return false;
    final verified = await _authenticator.authenticate(
      localizedReason: 'Enable biometric unlock for HealthPocket',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
    if (verified) {
      await _storage.write(key: 'hp.biometric.$uid', value: 'enabled');
    }
    return verified;
  }

  Future<bool> authenticate(String uid) async {
    if (!await isEnabled(uid) || !await isAvailable()) return false;
    return _authenticator.authenticate(
      localizedReason: 'Unlock HealthPocket',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<void> decline(String uid) =>
      _storage.write(key: 'hp.biometric.$uid', value: 'declined');
  Future<void> disable(String uid) => _storage.delete(key: 'hp.biometric.$uid');
}
