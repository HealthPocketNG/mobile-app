import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';

Future<void> showCareV2PartnerSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheetContext) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DBE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CareV2.mint,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                '${CareV2.assets}partner-c79d1.svg',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'What is a HealthPocket Partner?',
              textAlign: TextAlign.center,
              style: careText(20, FontWeight.w700, CareV2.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Partners are healthcare providers that have joined HealthPocket.',
              textAlign: TextAlign.center,
              style: careText(
                13.5,
                FontWeight.w400,
                CareV2.muted,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            const _PartnerBenefit(
              icon: 'partner-56095.svg',
              title: 'Verified by us',
              detail: "We've reviewed the provider and confirmed their account details.",
            ),
            const SizedBox(height: 14),
            const _PartnerBenefit(
              icon: 'partner-5c9f4.svg',
              title: 'Faster payments',
              detail: 'No merchant check is needed, so payments go through straight away.',
            ),
            const SizedBox(height: 14),
            const _PartnerBenefit(
              icon: 'partner-5c62c.svg',
              title: 'Easy to find',
              detail:
                  'Partners appear first when you search for care near you.',
            ),
            const SizedBox(height: 20),
            CareV2Button(
              label: 'Got it',
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _PartnerBenefit extends StatelessWidget {
  const _PartnerBenefit({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final String icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF9F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset('${CareV2.assets}$icon', width: 20, height: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: careText(14, FontWeight.w700, CareV2.navy)),
            const SizedBox(height: 2),
            Text(
              detail,
              style: careText(
                12.5,
                FontWeight.w400,
                CareV2.muted,
              ).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    ],
  );
}
