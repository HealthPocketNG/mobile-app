import 'package:flutter/material.dart';
import 'package:healthpocket/features/care/data/demo_care_directory_repository.dart';
import 'package:healthpocket/features/care/presentation/find_care_screen.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/presentation/auth_form_screen.dart';
import 'package:healthpocket/features/auth/presentation/app_pin_screen.dart';
import 'package:healthpocket/features/auth/presentation/pin_recovery_screen.dart';
import 'package:healthpocket/features/auth/presentation/splash_screen.dart';
import 'package:healthpocket/features/auth/presentation/welcome_screen.dart';
import 'package:healthpocket/features/auth/presentation/verify_email_screen.dart';
import 'package:healthpocket/features/auth/presentation/password_recovery_screen.dart';
import 'package:healthpocket/features/auth/presentation/auth_state_screen.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/activity/presentation/activity_screen.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/savings_plan_setup_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/personal_information_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/onboarding_complete_screen.dart';
import 'package:healthpocket/features/profile/presentation/profile_screen.dart';
import 'package:healthpocket/features/savings/presentation/savings_screen.dart';

enum AppRoute {
  splash('/'),
  welcome('/welcome'),
  signIn('/sign-in'),
  signUp('/sign-up'),
  verifyEmail('/verify-email'),
  forgotPassword('/forgot-password'),
  passwordResetSent('/password-reset-sent'),
  createNewPassword('/create-new-password'),
  sessionExpired('/session-expired'),
  offline('/offline'),
  accountLocked('/account-locked'),
  biometrics('/biometrics'),
  success('/success'),
  createPin('/create-pin'),
  unlockPin('/unlock-pin'),
  pinRecovery('/pin-recovery'),
  onboarding('/onboarding'),
  personalInformation('/onboarding/personal-information'),
  savingsPlanSetup('/onboarding/savings-plan'),
  onboardingComplete('/onboarding/complete'),
  dashboard('/dashboard'),
  activity('/activity'),
  savings('/savings'),
  familyPocket('/family-pocket'),
  findCare('/find-care'),
  profile('/profile');

  const AppRoute(this.path);
  final String path;
}

class AppRouter {
  AppRouter(this.appState);

  final AppState appState;

  Route<void> onGenerateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '/');
    final resetLink =
        (uri?.scheme == 'healthpocket' && uri?.host == 'reset-password') ||
        uri?.path == '/reset-password';
    final route = AppRoute.values.where((item) => item.path == uri?.path);
    final destination = resetLink
        ? AppRoute.createNewPassword
        : route.isEmpty
        ? AppRoute.splash
        : route.first;
    final guardedDestination = _guard(destination);

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => FamilyInvitationScope(
        store: appState.familyPocketStore,
        child: switch (guardedDestination) {
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
          AppRoute.verifyEmail => VerifyEmailScreen(appState: appState),
          AppRoute.forgotPassword => PasswordRecoveryScreen(
            appState: appState,
            step: PasswordRecoveryStep.request,
          ),
          AppRoute.passwordResetSent => PasswordRecoveryScreen(
            appState: appState,
            step: PasswordRecoveryStep.sent,
            email: settings.arguments as String?,
          ),
          AppRoute.createNewPassword => PasswordRecoveryScreen(
            appState: appState,
            step: PasswordRecoveryStep.create,
            resetCode:
                settings.arguments as String? ?? uri?.queryParameters['token'],
          ),
          AppRoute.sessionExpired => AuthStateScreen(
            kind: AuthStateKind.sessionExpired,
            appState: appState,
          ),
          AppRoute.offline => AuthStateScreen(
            kind: AuthStateKind.offline,
            appState: appState,
          ),
          AppRoute.accountLocked => AuthStateScreen(
            kind: AuthStateKind.accountLocked,
            appState: appState,
            lockedUntil: settings.arguments as DateTime?,
          ),
          AppRoute.biometrics => AuthStateScreen(
            kind: AuthStateKind.biometrics,
            appState: appState,
          ),
          AppRoute.success => AuthStateScreen(
            kind: AuthStateKind.success,
            appState: appState,
          ),
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
            onCompleted: appState.completeProfileOnboarding,
          ),
          AppRoute.personalInformation => PersonalInformationScreen(
            profileStore: appState.profileStore,
            onCompleted: appState.completeProfileOnboarding,
          ),
          AppRoute.savingsPlanSetup => SavingsPlanSetupScreen(
            savingsStore: appState.savingsStore,
            onCompleted: appState.completeOnboarding,
          ),
          AppRoute.onboardingComplete => const OnboardingCompleteScreen(),
          AppRoute.dashboard => DashboardScreen(
            savingsStore: appState.savingsStore,
            profileStore: appState.profileStore,
            developmentContributionsEnabled:
                appState.developmentContributionsEnabled,
            onRetryContributions: appState.retryContributionLoad,
            onRefresh: appState.refreshDashboard,
          ),
          AppRoute.activity => ActivityScreen(
            savingsStore: appState.savingsStore,
            familyStore: appState.familyPocketStore,
          ),
          AppRoute.savings => SavingsScreen(
            store: appState.savingsStore,
            onSavePlan: appState.updateSavingsPlan,
            onTogglePlan: appState.toggleSavingsPlan,
            developmentContributionsEnabled:
                appState.developmentContributionsEnabled,
            onCreateContributionKey: appState.createDevelopmentContributionKey,
            onRecordDevelopmentContribution:
                appState.recordDevelopmentContribution,
            onRetryContributions: appState.retryContributionLoad,
          ),
          AppRoute.familyPocket => FamilyPocketScreen(
            store: appState.familyPocketStore,
            onCreatePocket: appState.createFamilyPocket,
            onInviteMember: appState.inviteFamilyMember,
            onRespondToInvitation: appState.respondToFamilyInvitation,
            onCancelInvitation: appState.cancelFamilyInvitation,
            onRemoveMember: appState.removeFamilyMember,
            onRecordDevelopmentContribution: (amountNaira) =>
                appState.recordDevelopmentFamilyContribution(
                  amountNaira: amountNaira,
                  idempotencyKey: appState.createDevelopmentContributionKey(),
                ),
            onRefresh: appState.refreshFamilyPockets,
            developmentContributionsEnabled:
                appState.developmentContributionsEnabled,
          ),
          AppRoute.profile => ProfileScreen(
            onSaveAccount: appState.updateAccountDetails,
            onSavePersonalDetails: appState.updatePersonalDetails,
            // Live uploads stay disabled until the DEV Storage bucket exists.
            // Existing paths can render; otherwise Google photo/initials wins.
            profilePhotoRepository: appState.profilePhotoRepository,
            providerPhotoUrl: appState.authRepository.currentUser?.photoUrl,
            store: appState.profileStore,
            authRepository: appState.authRepository,
            onSignOut: appState.signOut,
            onSaveNotificationPreferences:
                appState.updateNotificationPreferences,
          ),
          AppRoute.findCare => FindCareScreen(
            repository:
                appState.careDirectoryRepository ??
                const DemoCareDirectoryRepository(),
            demoRequestsEnabled: appState.developmentContributionsEnabled,
            savingsStore: appState.savingsStore,
          ),
        },
      ),
    );
  }

  AppRoute _guard(AppRoute destination) {
    const protected = {
      AppRoute.createPin,
      AppRoute.unlockPin,
      AppRoute.pinRecovery,
      AppRoute.dashboard,
      AppRoute.activity,
      AppRoute.savings,
      AppRoute.familyPocket,
      AppRoute.findCare,
      AppRoute.profile,
    };
    if (!protected.contains(destination) || appState.canAccessProtectedFlows) {
      return destination;
    }
    return appState.authRepository.currentUser == null
        ? AppRoute.welcome
        : AppRoute.personalInformation;
  }
}

AppRoute appRouteForAuthFlow(AuthFlowDestination destination) =>
    switch (destination) {
      AuthFlowDestination.welcome => AppRoute.welcome,
      AuthFlowDestination.sessionExpired => AppRoute.sessionExpired,
      AuthFlowDestination.verifyEmail => AppRoute.verifyEmail,
      AuthFlowDestination.personalInformation => AppRoute.personalInformation,
      AuthFlowDestination.createPin => AppRoute.createPin,
      AuthFlowDestination.unlockPin => AppRoute.unlockPin,
    };
