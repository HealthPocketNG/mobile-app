import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';

/// Shared V2 explanation sheet for non-partner payment and verification.
Future<void> showCareExplanationSheet(
  BuildContext context, {
  required bool verification,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => _CareExplanationSheet(verification: verification),
);

class _CareExplanationSheet extends StatelessWidget {
  const _CareExplanationSheet({required this.verification});
  final bool verification;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                '${CareV2.assets}${verification ? 'verify-1ed36.svg' : 'learn-41e94.svg'}',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              verification
                  ? 'How merchant verification works'
                  : "Paying a provider that isn't a partner",
              textAlign: TextAlign.center,
              style: careText(20, FontWeight.w700, CareV2.navy),
            ),
            const SizedBox(height: 10),
            Text(
              verification
                  ? 'HealthPocket money is for healthcare. We make sure it only goes to healthcare providers.'
                  : "You can pay any healthcare provider with HealthPocket, even if they haven't joined us yet.",
              textAlign: TextAlign.center,
              style: careText(
                13.5,
                FontWeight.w400,
                CareV2.muted,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            if (verification) ...[
              const _SheetPoint(
                asset: 'verify-7d296.svg',
                title: 'What is an MCC?',
                detail: 'A 4-digit merchant category code that banks give every business to describe what it does, like a pharmacy or hospital.',
              ),
              const _SheetPoint(
                asset: 'verify-5c62c.svg',
                title: 'What we check',
                detail: "We confirm the merchant's code belongs to a healthcare category before sending your money.",
              ),
              const _SheetPoint(
                asset: 'verify-03cc8.svg',
                title: 'How long it takes',
                detail: "Usually a few seconds. If it takes longer, we'll notify you.",
              ),
            ] else ...[
              const _SheetPoint(
                asset: 'learn-0b343.svg',
                title: 'Pay by bank transfer',
                detail: "Enter the provider's account details and pay from your HealthPocket balance.",
              ),
              const _SheetPoint(
                asset: 'learn-6fdce.svg',
                title: "We check they're healthcare",
                detail: 'Before the payment is completed, we verify the merchant is a healthcare provider.',
              ),
              const _SheetPoint(
                asset: 'learn-019b1.svg',
                title: 'Your money stays safe',
                detail: "If the check doesn't pass, the payment is cancelled and the full amount returns to your balance.",
              ),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF9F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    '${CareV2.assets}${verification ? 'verify-00c69.svg' : 'learn-00d6a.svg'}',
                    width: 14,
                    height: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      verification
                          ? "Verified HealthPocket partners don't need this check."
                          : "HealthPocket partners skip this check because we've already verified them.",
                      style: careText(
                        12,
                        FontWeight.w400,
                        CareV2.muted,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CareV2Button(
              label: 'Got it',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetPoint extends StatelessWidget {
  const _SheetPoint({
    required this.asset,
    required this.title,
    required this.detail,
  });
  final String asset, title, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
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
          child: SvgPicture.asset(
            '${CareV2.assets}$asset',
            width: 20,
            height: 20,
          ),
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
    ),
  );
}
