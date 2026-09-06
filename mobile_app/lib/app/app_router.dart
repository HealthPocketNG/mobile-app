import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';

enum AppRoute {
  splash('/'),
  welcome('/welcome'),
  signIn('/sign-in'),
  signUp('/sign-up'),
  forgotPassword('/forgot-password'),
  otp('/otp'),
  onboarding('/onboarding'),
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
        AppRoute.splash => const _SplashScreen(),
        _ => _FoundationScreen(route: destination),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('HealthPocket', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Build a healthcare fund before you need it.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Get started',
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoute.welcome.path,
                ),
              ),
            ],
          ),
        ),
      ),
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
