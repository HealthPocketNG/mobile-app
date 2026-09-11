import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/presentation/auth_form_screen.dart';
import 'package:healthpocket/features/auth/presentation/app_pin_screen.dart';
import 'package:healthpocket/features/auth/presentation/email_verification_screen.dart';
import 'package:healthpocket/features/auth/presentation/forgot_password_screen.dart';
import 'package:healthpocket/features/auth/presentation/pin_recovery_screen.dart';
import 'package:healthpocket/features/auth/presentation/splash_screen.dart';
import 'package:healthpocket/features/auth/presentation/welcome_screen.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/savings_plan_setup_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/personal_information_screen.dart';
import 'package:healthpocket/features/profile/presentation/profile_screen.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';

enum AppRoute {
  splash('/'),
  welcome('/welcome'),
  signIn('/sign-in'),
  signUp('/sign-up'),
  forgotPassword('/forgot-password'),
  verifyEmail('/verify-email'),
  createPin('/create-pin'),
  unlockPin('/unlock-pin'),
  pinRecovery('/pin-recovery'),
  onboarding('/onboarding'),
  personalInformation('/onboarding/personal-information'),
  savingsPlanSetup('/onboarding/savings-plan'),
  dashboard('/dashboard'),
  savings('/savings'),
  familyPocket('/family-pocket'),
  profile('/profile');

  const AppRoute(this.path);
  final String path;
}

class AppRouter {
  AppRouter(this.appState);

  final AppState appState;

  Route<void> onGenerateRoute(RouteSettings settings) {
    final route = AppRoute.values.where((item) => item.path == settings.name);
    final destination = route.isEmpty ? AppRoute.splash : route.first;

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => switch (destination) {
        AppRoute.splash => SplashScreen(appState: appState),
        AppRoute.welcome => const WelcomeScreen(),
        AppRoute.signIn => AuthFormScreen(
          mode: AuthMode.signIn,
          appState: appState,
        ),
        AppRoute.signUp => AuthFormScreen(
          mode: AuthMode.signUp,
          appState: appState,
        ),
        AppRoute.forgotPassword => ForgotPasswordScreen(
          authRepository: appState.authRepository,
        ),
        AppRoute.verifyEmail => EmailVerificationScreen(appState: appState),
        AppRoute.createPin => AppPinScreen(
          appState: appState,
          mode: AppPinMode.create,
        ),
        AppRoute.unlockPin => AppPinScreen(
          appState: appState,
          mode: AppPinMode.unlock,
        ),
        AppRoute.pinRecovery => PinRecoveryScreen(appState: appState),
        AppRoute.onboarding => PersonalInformationScreen(
          profileStore: appState.profileStore,
        ),
        AppRoute.personalInformation => PersonalInformationScreen(
          profileStore: appState.profileStore,
        ),
        AppRoute.savingsPlanSetup => SavingsPlanSetupScreen(
          savingsStore: appState.savingsStore,
          onCompleted: appState.completeOnboarding,
        ),
        AppRoute.dashboard => DashboardScreen(
          savingsStore: appState.savingsStore,
          profileStore: appState.profileStore,
        ),
        AppRoute.savings => SavingsScreen(
          store: appState.savingsStore,
          onSavePlan: appState.updateSavingsPlan,
          onTogglePlan: appState.toggleSavingsPlan,
        ),
        AppRoute.familyPocket => FamilyPocketScreen(
          store: appState.familyPocketStore,
        ),
        AppRoute.profile => ProfileScreen(
          store: appState.profileStore,
          authRepository: appState.authRepository,
        ),
      },
    );
  }
}

AppRoute appRouteForAuthFlow(AuthFlowDestination destination) =>
    switch (destination) {
      AuthFlowDestination.welcome => AppRoute.welcome,
      AuthFlowDestination.verifyEmail => AppRoute.verifyEmail,
      AuthFlowDestination.personalInformation => AppRoute.personalInformation,
      AuthFlowDestination.createPin => AppRoute.createPin,
      AuthFlowDestination.unlockPin => AppRoute.unlockPin,
    };
