import 'package:healthpocket/firebase/firebase_bootstrap.dart';
import 'package:healthpocket/firebase/firebase_options_prod.dart' as production;

Future<void> main() => bootstrapFirebase(
  environment: AppEnvironment.production,
  options: production.DefaultFirebaseOptions.currentPlatform,
);
