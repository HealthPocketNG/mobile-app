import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/firebase/firebase_bootstrap.dart';

void main() {
  const devOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'healthpocket-dev-a82f3',
  );
  const prodOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'healthpocket-ng',
  );

  test('accepts the development project in a non-release build', () {
    expect(
      () => FirebaseConfigurationGuard.validate(
        environment: AppEnvironment.development,
        options: devOptions,
        isReleaseMode: false,
        flavor: 'dev',
      ),
      returnsNormally,
    );
  });

  test('rejects production Firebase outside a release build', () {
    expect(
      () => FirebaseConfigurationGuard.validate(
        environment: AppEnvironment.production,
        options: prodOptions,
        isReleaseMode: false,
        flavor: 'prod',
      ),
      throwsStateError,
    );
  });

  test('rejects a Firebase project assigned to the wrong environment', () {
    expect(
      () => FirebaseConfigurationGuard.validate(
        environment: AppEnvironment.development,
        options: prodOptions,
        isReleaseMode: true,
        flavor: 'dev',
      ),
      throwsStateError,
    );
  });

  test('rejects an entrypoint paired with the wrong Android flavor', () {
    expect(
      () => FirebaseConfigurationGuard.validate(
        environment: AppEnvironment.production,
        options: prodOptions,
        isReleaseMode: true,
        flavor: 'dev',
      ),
      throwsStateError,
    );
  });

  test('allows emulators only for the development environment', () {
    expect(
      () => FirebaseConfigurationGuard.validateEmulatorUse(
        environment: AppEnvironment.development,
        useEmulators: true,
      ),
      returnsNormally,
    );
    expect(
      () => FirebaseConfigurationGuard.validateEmulatorUse(
        environment: AppEnvironment.production,
        useEmulators: true,
      ),
      throwsStateError,
    );
  });
}
