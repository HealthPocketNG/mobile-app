import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/onboarding/celebratoryOnboarding.png',
                height: 250,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'You’re all set!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Welcome to HealthPocket.\nTogether, for a healthier tomorrow.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.inkMuted, height: 1.45),
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Go to Dashboard  →',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoute.dashboard.path,
                  (route) => false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
