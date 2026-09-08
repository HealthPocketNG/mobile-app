import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.centered = false,
    this.showTagline = false,
  });

  final bool centered;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _BrandMark(),
        const SizedBox(width: AppSpacing.sm),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink),
            children: const [
              TextSpan(text: 'Health'),
              TextSpan(
                text: 'Pocket',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        logo,
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Save today. Healthier tomorrow.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 38,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 1,
            child: Container(
              width: 13,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 9,
            top: 13,
            child: Container(
              width: 17,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 1,
            child: Container(
              width: 25,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 10,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
