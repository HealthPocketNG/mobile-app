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
    appState.profileStore.beginRegistration(
      fullName: 'Private Name',
      email: 'private@example.com',
      phoneNumber: '08000000000',
      emailVerified: true,
    );
    await appState.signOut();

    expect(await appState.resolveStartup(), AuthFlowDestination.welcome);
    expect(appState.profileStore.profile.fullName, isEmpty);
    expect(appState.profileStore.profile.email, isEmpty);
    expect(appState.savingsStore.plan, isNull);
    expect(appState.familyPocketStore.pockets, isEmpty);
  });

  test('logout blocks PIN-only re-entry until Google signs in again', () async {
    final result = await auth.signInWithGoogle();
    await appState.acceptAuthentication(result!);
    await appState.setPin('482913');

    await appState.signOut();

    expect(appState.verifyPin('482913'), throwsA(isA<AuthFailure>()));

    final signedInAgain = await auth.signInWithGoogle();
    await appState.acceptAuthentication(signedInAgain!);
    expect((await appState.verifyPin('482913')).isValid, isTrue);
  });

  test('an expired Firebase session cannot be replaced by a PIN', () async {
    final result = await auth.signInWithGoogle();
    await appState.acceptAuthentication(result!);
    await appState.setPin('482913');

    await auth.signOut();

    expect(await appState.resolveStartup(), AuthFlowDestination.welcome);
    expect(appState.verifyPin('482913'), throwsA(isA<AuthFailure>()));
  });

  test('Google reauthentication clears the old PIN before reset', () async {
    final result = await auth.signInWithGoogle();
    await appState.acceptAuthentication(result!);
    await appState.setPin('482913');

    expect(await appState.reauthenticateAndResetPin(), isTrue);
    expect(await appState.resolveStartup(), AuthFlowDestination.createPin);
  });
}
