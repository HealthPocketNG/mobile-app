import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 0,
                child: Opacity(
                  opacity: 0,
                  child: Text('Prepare for medical bills before they happen.'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A healthier\ntomorrow, together.',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.05),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Save, pay and access quality healthcare — all in one place.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.inkMuted, height: 1.45),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Expanded(child: _WelcomeIllustration()),
              const SizedBox(height: AppSpacing.md),
              const Center(child: _PageDots()),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'Get started',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoute.signUp.path),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoute.signIn.path),
                  child: const Text('Already have an account? Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Image.asset(
          'assets/onboarding/onboarding.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 5),
        ...List.generate(
          3,
          (_) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(
              color: AppColors.outline,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
