import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/features/auth/presentation/auth_form_screen.dart';
import 'package:healthpocket/features/auth/presentation/forgot_password_screen.dart';
import 'package:healthpocket/features/auth/presentation/otp_verification_screen.dart';
import 'package:healthpocket/features/auth/presentation/splash_screen.dart';
import 'package:healthpocket/features/auth/presentation/welcome_screen.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/goal_setup_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/kyc_screen.dart';
import 'package:healthpocket/features/onboarding/presentation/personal_information_screen.dart';
import 'package:healthpocket/features/savings/presentation/savings_goals_screen.dart';

enum AppRoute {
  splash('/'),
  welcome('/welcome'),
  signIn('/sign-in'),
  signUp('/sign-up'),
  forgotPassword('/forgot-password'),
  otp('/otp'),
  onboarding('/onboarding'),
  personalInformation('/onboarding/personal-information'),
  kyc('/onboarding/kyc'),
  goalSetup('/onboarding/goal-setup'),
  dashboard('/dashboard'),
  goals('/goals'),
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
        AppRoute.splash => const SplashScreen(),
        AppRoute.welcome => const WelcomeScreen(),
        AppRoute.signIn => const AuthFormScreen(mode: AuthMode.signIn),
        AppRoute.signUp => const AuthFormScreen(mode: AuthMode.signUp),
        AppRoute.forgotPassword => const ForgotPasswordScreen(),
        AppRoute.otp => const OtpVerificationScreen(),
        AppRoute.onboarding => const PersonalInformationScreen(),
        AppRoute.personalInformation => const PersonalInformationScreen(),
        AppRoute.kyc => const KycScreen(),
        AppRoute.goalSetup => const GoalSetupScreen(),
        AppRoute.dashboard => DashboardScreen(
          savingsStore: appState.savingsStore,
        ),
        AppRoute.goals => SavingsGoalsScreen(store: appState.savingsStore),
        AppRoute.familyPocket => FamilyPocketScreen(
          store: appState.familyPocketStore,
        ),
        _ => _FoundationScreen(route: destination),
      },
    );
  }
}

class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen({required this.route});

  final AppRoute route;

  @override
  Widget build(BuildContext context) {
    final title = route.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .replaceFirstMapped(
          RegExp(r'^.'),
          (match) => match.group(0)!.toUpperCase(),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('HealthPocket')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This route is ready for its feature screen. The design system, '
              'navigation, and app state are in place.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
