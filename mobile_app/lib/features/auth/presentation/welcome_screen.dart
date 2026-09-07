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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoute.signIn.path),
                  child: const Text('Skip'),
                ),
              ),
              Text(
                'Prepare for medical\nbills before they happen.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Save consistently and build a healthier future for you and your family.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Expanded(child: _WelcomeIllustration()),
              const SizedBox(height: AppSpacing.md),
              const Center(child: _PageDots()),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'Get started',
                onPressed: () => Navigator.pushNamed(context, AppRoute.signUp.path),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoute.signIn.path),
                  child: const Text('I already have an account'),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: 24,
            top: 22,
            child: CircleAvatar(
              radius: 27,
              backgroundColor: Colors.white,
              child: Icon(Icons.favorite_rounded, color: AppColors.secondary),
            ),
          ),
          Positioned(
            left: 28,
            top: 30,
            bottom: 34,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 126,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22045E5B), blurRadius: 20, offset: Offset(0, 12)),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 94,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.health_and_safety_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'A healthier tomorrow starts today.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            right: 34,
            bottom: 30,
            child: Icon(Icons.person_rounded, size: 126, color: AppColors.primary),
          ),
          const Positioned(
            right: 105,
            bottom: 17,
            child: Icon(Icons.eco_rounded, size: 72, color: Color(0xFF68C9B2)),
          ),
        ],
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
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 5),
        ...List.generate(
          3,
          (_) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}
