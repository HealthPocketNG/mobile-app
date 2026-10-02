import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

void main() {
  late InMemoryAuthRepository auth;
  late AppState appState;

  setUp(() {
    auth = InMemoryAuthRepository();
    appState = AppState(
      authRepository: auth,
      pinRepository: SecureAppPinRepository(storage: MemorySecureValueStore()),
    );
  });

  tearDown(() {
    appState.dispose();
    auth.dispose();
  });

  test('new Google account starts onboarding', () async {
    final signedIn = await auth.signInWithGoogle();
    final result = AuthResult(user: signedIn!.user, isNewUser: true);

    expect(
      await appState.acceptAuthentication(result),
      AuthFlowDestination.personalInformation,
    );
    expect(appState.profileStore.profile.emailVerified, isTrue);
  });

  test('restores a Firebase session and requires the local PIN', () async {
    final result = await auth.signInWithGoogle();
    expect(
      await appState.acceptAuthentication(result!),
      AuthFlowDestination.createPin,
    );

    await appState.setPin('482913');

    expect(await appState.resolveStartup(), AuthFlowDestination.unlockPin);
    expect((await appState.verifyPin('482913')).isValid, isTrue);
  });

  test('sign-out returns startup routing to welcome', () async {
    await auth.signInWithGoogle();
    await appState.signOut();

    expect(await appState.resolveStartup(), AuthFlowDestination.welcome);
  });
}
