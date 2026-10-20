import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

void main() {
  test(
    'new Google user completes onboarding, restores with PIN, then logout blocks PIN',
    () async {
      final auth = InMemoryAuthRepository();
      final state = AppState(
        authRepository: auth,
        pinRepository: SecureAppPinRepository(
          storage: MemorySecureValueStore(),
        ),
      );
      addTearDown(state.dispose);
      addTearDown(auth.dispose);

      final signedIn = await auth.signInWithGoogle();
      expect(
        await state.acceptAuthentication(
          AuthResult(user: signedIn!.user, isNewUser: true),
        ),
        AuthFlowDestination.personalInformation,
      );

      state.profileStore.updatePersonalInformation(
        dateOfBirth: DateTime(1995, 4, 18),
        gender: 'female',
        residentialAddress: '21 Journey Road',
        stateOfResidence: 'Lagos',
        nextOfKinName: 'Chidi Okafor',
        nextOfKinPhone: '+2348098765432',
      );
      state.savingsStore.saveOnboardingPlan(
        contributionAmountKobo: 50000,
        frequency: SavingsFrequency.monthly,
        startDate: DateTime(2026, 11, 1),
      );
      await state.completeOnboarding();
      await state.setPin('482913');

      expect(state.canAccessProtectedFlows, isTrue);
      expect(await state.resolveStartup(), AuthFlowDestination.unlockPin);
      expect((await state.verifyPin('482913')).isValid, isTrue);

      await state.signOut();
      expect(await state.resolveStartup(), AuthFlowDestination.welcome);
      await expectLater(state.verifyPin('482913'), throwsA(isA<AuthFailure>()));
    },
  );
}
