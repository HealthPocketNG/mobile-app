import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:healthpocket/app/health_pocket_app.dart';
import 'package:healthpocket/core/data/firestore/firestore_repositories.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';

enum AppEnvironment { development, production }

const _useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);
const _firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

abstract final class FirebaseConfigurationGuard {
  static const _expectedProjectIds = <AppEnvironment, String>{
    AppEnvironment.development: 'healthpocket-dev-a82f3',
    AppEnvironment.production: 'healthpocket-ng',
  };
  static const _expectedFlavors = <AppEnvironment, String>{
    AppEnvironment.development: 'dev',
    AppEnvironment.production: 'prod',
  };

  static void validate({
    required AppEnvironment environment,
    required FirebaseOptions options,
    required bool isReleaseMode,
    required String? flavor,
  }) {
    final expectedFlavor = _expectedFlavors[environment];
    if (flavor != expectedFlavor) {
      throw StateError(
        'Build flavor mismatch: ${environment.name} must use '
        '--flavor $expectedFlavor, not ${flavor ?? 'no flavor'}.',
      );
    }

    final expectedProjectId = _expectedProjectIds[environment];
    if (options.projectId != expectedProjectId) {
      throw StateError(
        'Firebase configuration mismatch: ${environment.name} must use '
        '$expectedProjectId, not ${options.projectId}.',
      );
    }

    if (environment == AppEnvironment.production && !isReleaseMode) {
      throw StateError('Production Firebase is restricted to release builds.');
    }
  }

  static void validateEmulatorUse({
    required AppEnvironment environment,
    required bool useEmulators,
  }) {
    if (useEmulators && environment != AppEnvironment.development) {
      throw StateError('Firebase emulators are restricted to DEV builds.');
    }
  }
}

Future<void> bootstrapFirebase({
  required AppEnvironment environment,
  required FirebaseOptions options,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseConfigurationGuard.validate(
    environment: environment,
    options: options,
    isReleaseMode: kReleaseMode,
    flavor: appFlavor,
  );
  FirebaseConfigurationGuard.validateEmulatorUse(
    environment: environment,
    useEmulators: _useFirebaseEmulators,
  );
  await Firebase.initializeApp(options: options);
  if (_useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(
      _firebaseEmulatorHost,
      8080,
    );
  }
  final authRepository = await FirebaseAuthRepository.initialize(
    FirebaseAuth.instance,
  );
  final repositories = FirebaseRepositoryBundle(
    auth: authRepository,
    firestore: FirebaseFirestore.instance,
  );
  runApp(
    HealthPocketApp(
      authRepository: authRepository,
      pinRepository: SecureAppPinRepository(storage: FlutterSecureValueStore()),
      profileRepository: repositories.profiles,
      savingsRepository: repositories.savings,
      contributionRepository: repositories.contributions,
      familyPocketRepository: repositories.familyPockets,
      developmentContributionsEnabled:
          environment == AppEnvironment.development,
    ),
  );
}
