import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/widgets/onboarding_step_header.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            children: [
              const OnboardingStepHeader(title: 'Complete demo KYC', step: 3),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 46),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Verify your identity (Demo)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This shows how verification will work. No identity data is collected in this UI MVP.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _KycTask(
                icon: Icons.badge_outlined,
                title: 'Select ID type',
                subtitle: 'NIN, driver’s licence or passport',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _KycTask(
                icon: Icons.upload_file_outlined,
                title: 'Upload ID',
                subtitle: 'Take or upload a clear photo',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _KycTask(
                icon: Icons.face_retouching_natural_outlined,
                title: 'Selfie check',
                subtitle: 'Take a selfie for verification',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _KycTask(
                icon: Icons.location_on_outlined,
                title: 'Confirm address',
                subtitle: 'Verify your residential address',
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Submit demo KYC',
                onPressed: () => Navigator.pushNamed(context, AppRoute.goalSetup.path),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycTask extends StatelessWidget {
  const _KycTask({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 21),
        ],
      ),
    );
  }
}
