import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';
import 'package:healthpocket/features/care/presentation/care_v2_explanation_sheet.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';

enum CareNonPartnerOutcome { success, inReview, notCompleted, failed }

/// The current caller only has mock verification, so these screens are UI
/// previews. No status, reference, receipt, charge, or refund is fabricated.
class CareV2NonPartnerOutcomeScreen extends StatelessWidget {
  const CareV2NonPartnerOutcomeScreen({
    required this.provider,
    required this.amountKobo,
    required this.outcome,
    required this.onDone,
    required this.onRetry,
    super.key,
  });

  final CareProvider provider;
  final int amountKobo;
  final CareNonPartnerOutcome outcome;
  final VoidCallback onDone;
  final VoidCallback onRetry;

  void _goTo(BuildContext context, AppRoute route) =>
      Navigator.pushNamedAndRemoveUntil(context, route.path, (_) => false);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              outcome == CareNonPartnerOutcome.success ? 8 : 20,
              20,
              24,
            ),
            children: [
              if (outcome == CareNonPartnerOutcome.success)
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: onDone,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Tooltip(
                          message: 'Close',
                          child: SvgPicture.asset(
                            '${CareV2.assets}non-success-37dd3.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: math.max(0, math.min(60, (height - 640) * .3)),
                ),
              const SizedBox(height: 10),
              _art(),
              const SizedBox(height: 12),
              Text(
                switch (outcome) {
                  CareNonPartnerOutcome.success => 'Payment Successful!',
                  CareNonPartnerOutcome.inReview => 'Payment in review',
                  CareNonPartnerOutcome.notCompleted =>
                    'Merchant could not be verified',
                  CareNonPartnerOutcome.failed => 'Payment failed',
                },
                textAlign: TextAlign.center,
                style: careText(20, FontWeight.w700, CareV2.navy),
              ),
              const SizedBox(height: 8),
              Text(
                switch (outcome) {
                  CareNonPartnerOutcome.success =>
                    'This is how a completed payment to ${provider.name} will appear.',
                  CareNonPartnerOutcome.inReview =>
                    "We're checking that ${provider.name} is a healthcare provider.\nThis is taking a little longer than usual.",
                  CareNonPartnerOutcome.notCompleted =>
                    "We couldn't complete this payment because ${provider.name} isn't an eligible healthcare provider.",
                  CareNonPartnerOutcome.failed => "Something went wrong while sending your payment. You haven't been charged.",
                },
                textAlign: TextAlign.center,
                style: careText(
                  13.5,
                  FontWeight.w400,
                  CareV2.muted,
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              _PreviewNotice(message: 'UI preview only · No payment was sent'),
              const SizedBox(height: 18),
              if (outcome == CareNonPartnerOutcome.success)
                _successDetails()
              else
                _statusDetails(),
              if (outcome == CareNonPartnerOutcome.inReview ||
                  outcome == CareNonPartnerOutcome.notCompleted) ...[
                const SizedBox(height: 14),
                _PreviewNotice(
                  message: outcome == CareNonPartnerOutcome.inReview
                      ? 'No money is on hold in this preview. A live payment will show its confirmed status here.'
                      : 'No funds moved in this preview. Healthcare eligibility will be checked by the trusted payment service.',
                  asset: outcome == CareNonPartnerOutcome.inReview
                      ? 'in-review-e71fa.svg'
                      : 'not-completed-b36c1.svg',
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (outcome == CareNonPartnerOutcome.success) ...[
                  _OutcomeSecondaryButton(
                    label: 'View Receipt',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No receipt is available for this UI preview.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CareV2Button(label: 'Done', onPressed: onDone),
                ] else ...[
                  CareV2Button(
                    label: switch (outcome) {
                      CareNonPartnerOutcome.inReview => 'Back to Home',
                      CareNonPartnerOutcome.notCompleted =>
                        'Try Another Provider',
                      CareNonPartnerOutcome.failed => 'Try Again',
                      _ => throw StateError('Unexpected outcome'),
                    },
                    arrowAsset: outcome == CareNonPartnerOutcome.notCompleted
                        ? 'not-completed-ed152.svg'
                        : null,
                    onPressed: () {
                      if (outcome == CareNonPartnerOutcome.inReview) {
                        _goTo(context, AppRoute.dashboard);
                      } else if (outcome ==
                          CareNonPartnerOutcome.notCompleted) {
                        _goTo(context, AppRoute.findCare);
                      } else {
                        onRetry();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _OutcomeSecondaryButton(
                    label: switch (outcome) {
                      CareNonPartnerOutcome.inReview => 'View Activity',
                      CareNonPartnerOutcome.notCompleted =>
                        'How verification works',
                      CareNonPartnerOutcome.failed => 'Contact Support',
                      _ => throw StateError('Unexpected outcome'),
                    },
                    onPressed: () {
                      if (outcome == CareNonPartnerOutcome.inReview) {
                        _goTo(context, AppRoute.activity);
                      } else if (outcome ==
                          CareNonPartnerOutcome.notCompleted) {
                        showCareExplanationSheet(context, verification: true);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const SupportScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _art() {
    if (outcome == CareNonPartnerOutcome.success) {
      return SizedBox(
        height: 148,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: CareV2.teal,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    '${CareV2.assets}non-success-f0108.svg',
                    width: 40,
                    height: 40,
                  ),
                ),
                const Positioned(
                  left: 5,
                  top: 16,
                  child: _Confetti(color: CareV2.teal, angle: -.6),
                ),
                const Positioned(
                  right: 5,
                  top: 14,
                  child: _Confetti(color: Color(0xFFE8405F), angle: .6),
                ),
                const Positioned(
                  left: 10,
                  bottom: 18,
                  child: _Confetti(color: Color(0xFFE8405F), angle: .4),
                ),
                const Positioned(
                  right: 5,
                  bottom: 24,
                  child: _Confetti(color: CareV2.teal, angle: -.5),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final asset = switch (outcome) {
      CareNonPartnerOutcome.inReview => 'in-review-36e4b.png',
      CareNonPartnerOutcome.notCompleted => 'not-completed-26f87.png',
      CareNonPartnerOutcome.failed => 'failed-19263.png',
      _ => throw StateError('Unexpected outcome'),
    };
    return SizedBox(
      height: 180,
      child: Center(
        child: Image.asset(
          '${CareV2.assets}$asset',
          width: outcome == CareNonPartnerOutcome.failed ? 176 : 180,
          height: outcome == CareNonPartnerOutcome.failed ? 164 : 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _successDetails() => _OutcomeCard(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: CareProviderSummaryV2(
          provider: provider,
          badgeAsset: 'review-e0188.svg',
        ),
      ),
      _OutcomeRow(label: 'Amount', value: careMoney(amountKobo)),
      const _OutcomeRow(label: 'Date', value: '—'),
      const _OutcomeRow(
        label: 'Reference ID',
        value: '—',
        asset: 'non-success-399f6.svg',
      ),
      const _OutcomeRow(label: 'Payment method', value: 'Bank Transfer'),
      const _OutcomeRow(
        label: 'Status',
        value: 'Preview',
        last: true,
        statusColor: Color(0xFF0B7F7A),
        statusAsset: 'non-success-cd110.svg',
      ),
    ],
  );

  Widget _statusDetails() => _OutcomeCard(
    children: [
      if (outcome != CareNonPartnerOutcome.failed) ...[
        _OutcomeRow(label: 'Merchant', value: provider.name),
        _OutcomeRow(label: 'Amount', value: careMoney(amountKobo)),
      ],
      const _OutcomeRow(label: 'Reference ID', value: '—'),
      _OutcomeRow(
        label: 'Status',
        value: outcome == CareNonPartnerOutcome.inReview
            ? 'Preview'
            : 'Not charged',
        last: true,
        statusColor: outcome == CareNonPartnerOutcome.inReview
            ? const Color(0xFF9A6200)
            : const Color(0xFF008A44),
      ),
    ],
  );
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: CareV2.outline),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: children),
  );
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.label,
    required this.value,
    this.asset,
    this.last = false,
    this.statusColor,
    this.statusAsset,
  });
  final String label, value;
  final String? asset;
  final bool last;
  final Color? statusColor;
  final String? statusAsset;
  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: CareV2.outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: careText(12, FontWeight.w400, CareV2.muted),
          ),
        ),
        if (statusColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor == const Color(0xFF9A6200)
                  ? const Color(0xFFFFEBC8)
                  : const Color(0xFFE3F6EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusAsset != null) ...[
                  SvgPicture.asset(
                    '${CareV2.assets}$statusAsset',
                    width: 12,
                    height: 12,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(value, style: careText(11, FontWeight.w500, statusColor!)),
              ],
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: careText(13, FontWeight.w500, CareV2.navy),
            ),
          ),
        if (asset != null) ...[
          const SizedBox(width: 5),
          SvgPicture.asset('${CareV2.assets}$asset', width: 16, height: 16),
        ],
      ],
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.message, this.asset});
  final String message;
  final String? asset;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF9F7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        asset == null
            ? const Icon(Icons.info_outline, size: 20, color: CareV2.teal)
            : SvgPicture.asset('${CareV2.assets}$asset', width: 20, height: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: careText(
              12,
              FontWeight.w400,
              CareV2.muted,
            ).copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _OutcomeSecondaryButton extends StatelessWidget {
  const _OutcomeSecondaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(26),
    child: Container(
      width: double.infinity,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CareV2.mint,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Text(label, style: careText(15, FontWeight.w600, CareV2.teal)),
    ),
  );
}

class _Confetti extends StatelessWidget {
  const _Confetti({required this.color, required this.angle});
  final Color color;
  final double angle;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 5,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class CareV2MerchantVerificationScreen extends StatelessWidget {
  const CareV2MerchantVerificationScreen({required this.onBack, super.key});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onBack,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Tooltip(
                      message: 'Back',
                      child: SvgPicture.asset(
                        '${CareV2.assets}merchant-16de2.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Image.asset(
                '${CareV2.assets}merchant-0039d.png',
                width: 162,
                height: 162,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Verifying merchant',
              textAlign: TextAlign.center,
              style: careText(22, FontWeight.w700, CareV2.navy),
            ),
            const SizedBox(height: 16),
            Text(
              'Checking if this provider is a\nhealthcare business...',
              textAlign: TextAlign.center,
              style: careText(13.5, FontWeight.w400, CareV2.muted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF9F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  _VerificationRow(
                    asset: 'merchant-92f13.svg',
                    text: 'Valid account\ndetails',
                  ),
                  _VerificationRow(
                    asset: 'merchant-13162.svg',
                    text: 'Checking merchant category (MCC)',
                  ),
                  _VerificationRow(
                    asset: 'merchant-f627f.svg',
                    text: 'Confirming healthcare provider',
                  ),
                  _VerificationRow(
                    asset: 'merchant-5c927.svg',
                    text: 'Securing your payment',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This should only take a few seconds.',
              textAlign: TextAlign.center,
              style: careText(13, FontWeight.w400, CareV2.muted),
            ),
            const SizedBox(height: 10),
            Text(
              'UI preview · No payment is being sent',
              textAlign: TextAlign.center,
              style: careText(11, FontWeight.w400, CareV2.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({
    required this.asset,
    required this.text,
    this.last = false,
  });
  final String asset, text;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      children: [
        SizedBox(width: 16, child: SvgPicture.asset('${CareV2.assets}$asset')),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: careText(12.5, FontWeight.w400, CareV2.muted),
          ),
        ),
      ],
    ),
  );
}
