import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/health_pocket_app.dart';
import 'package:healthpocket/core/theme/app_theme.dart';
import 'package:healthpocket/core/data/firestore/firestore_repositories.dart';
import 'package:healthpocket/core/backend/firebase_functions_trusted_backend_client.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/firebase_email_verification_service.dart';
import 'package:healthpocket/features/auth/data/preview_auth_repository.dart';
import 'package:healthpocket/features/auth/presentation/splash_screen.dart';
import 'package:healthpocket/features/profile/data/firebase_profile_photo_repository.dart';

enum AppEnvironment { development, production }

const _useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);
const _previewAuthSetting = String.fromEnvironment(
  'DEV_PREVIEW_AUTH',
  defaultValue: 'auto',
);
const _firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

abstract final class FirebaseConfigurationGuard {
  static bool resolvePreviewMode({
    required AppEnvironment environment,
    required bool isReleaseMode,
    required String setting,
  }) {
    if (setting == 'auto') {
      return environment == AppEnvironment.development && !isReleaseMode;
    }
    if (setting == 'false') return false;
    if (setting != 'true') {
      throw StateError('DEV_PREVIEW_AUTH must be true or false.');
    }
    validatePreviewMode(
      environment: environment,
      isReleaseMode: isReleaseMode,
      enabled: true,
    );
    return true;
  }

  static void validatePreviewMode({
    required AppEnvironment environment,
    required bool isReleaseMode,
    required bool enabled,
  }) {
    if (enabled &&
        (environment != AppEnvironment.development || isReleaseMode)) {
      throw StateError(
        'Local auth preview is only available in DEV debug builds.',
      );
    }
  }

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
  final previewMode = FirebaseConfigurationGuard.resolvePreviewMode(
    environment: environment,
    isReleaseMode: kReleaseMode,
    setting: _previewAuthSetting,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: SplashArtwork()),
    ),
  );
  if (previewMode) {
    runApp(
      HealthPocketApp(
        authRepository: PreviewAuthRepository(),
        previewMode: true,
      ),
    );
    return;
  }
  await Firebase.initializeApp(options: options);
  final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
  if (_useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(
      _firebaseEmulatorHost,
      8080,
    );
    await FirebaseStorage.instance.useStorageEmulator(
      _firebaseEmulatorHost,
      9199,
    );
    functions.useFunctionsEmulator(_firebaseEmulatorHost, 5001);
  }
  final authRepository = await FirebaseAuthRepository.initialize(
    FirebaseAuth.instance,
    functions: functions,
  );
  final repositories = FirebaseRepositoryBundle(
    auth: authRepository,
    firestore: FirebaseFirestore.instance,
  );
  runApp(
    HealthPocketApp(
      authRepository: authRepository,
      emailVerificationService: FirebaseEmailVerificationService(functions),
      pinRepository: SecureAppPinRepository(storage: FlutterSecureValueStore()),
      profileRepository: repositories.profiles,
      profilePhotoRepository: FirebaseProfilePhotoRepository(
        FirebaseStorage.instance,
      ),
      savingsRepository: repositories.savings,
      contributionRepository: repositories.contributions,
      familyPocketRepository: repositories.familyPockets,
      careDirectoryRepository: repositories.careDirectory,
      backendClient: FirebaseFunctionsTrustedBackendClient(functions),
      developmentContributionsEnabled:
          environment == AppEnvironment.development,
    ),
  );
}
