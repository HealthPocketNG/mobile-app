import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/features/dashboard/domain/coverage_guide.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoverageDetailsScreen extends StatelessWidget {
  const CoverageDetailsScreen({required this.balanceKobo, super.key});

  final int balanceKobo;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('What your balance can cover')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Text(
          'Illustrative costs only. They are not insurance cover or a provider quote.',
          style: TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 24),
        if (eligibleDashboardCoverageForBalance(balanceKobo).isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              balanceKobo <= 0
                  ? 'Start saving to see the care your balance can cover.'
                  : 'You’re close! Continue saving to see the care your balance can cover.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          )
        else
          GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: eligibleDashboardCoverageForBalance(balanceKobo).length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .86,
          ),
          itemBuilder: (context, index) => _CoverageDetailCard(
            guide: eligibleDashboardCoverageForBalance(balanceKobo)[index],
            balanceKobo: balanceKobo,
          ),
        ),
      ],
    ),
  );
}

class _CoverageDetailCard extends StatelessWidget {
  const _CoverageDetailCard({required this.guide, required this.balanceKobo});
  final CoverageGuide guide;
  final int balanceKobo;

  @override
  Widget build(BuildContext context) {
    final covered = balanceKobo >= guide.referenceCost * 100;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SvgPicture.asset(guide.asset, height: 74, width: double.infinity, fit: BoxFit.contain),
        const Spacer(),
        Text(guide.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(guide.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          _formatNaira(guide.referenceCost),
          style: TextStyle(fontWeight: FontWeight.w800, color: covered ? AppColors.success : AppColors.primaryDark),
        ),
      ]),
    );
  }
}

String _formatNaira(int amount) => '₦${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
