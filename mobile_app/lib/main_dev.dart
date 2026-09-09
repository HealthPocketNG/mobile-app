import 'package:healthpocket/firebase/firebase_bootstrap.dart';
import 'package:healthpocket/firebase/firebase_options_dev.dart' as development;

Future<void> main() => bootstrapFirebase(
  environment: AppEnvironment.development,
  options: development.DefaultFirebaseOptions.currentPlatform,
);
