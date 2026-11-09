import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';

/// Payment states for the fictional provider preview. No authorization or
/// transfer is sent to a backend, and the entered digits are never persisted.
class CareV2PinPreview extends StatelessWidget {
  const CareV2PinPreview({
    required this.provider,
    required this.amountKobo,
    required this.enteredDigits,
    required this.onDigit,
    required this.onDelete,
    required this.onClose,
    super.key,
  });

  final CareProvider provider;
  final int amountKobo;
  final int enteredDigits;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Close payment preview',
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: SvgPicture.asset(
                        '${CareV2.assets}pin-c81db.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoundIcon(asset: 'pin-5b577.svg', size: 64, iconSize: 30),
                  const SizedBox(height: 20),
                  Text(
                    'Confirm payment',
                    style: careText(20, FontWeight.w700, CareV2.navy),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Enter your 4-digit demo PIN to preview\n',
                        ),
                        TextSpan(
                          text: careMoney(amountKobo),
                          style: careText(13.5, FontWeight.w700, CareV2.navy),
                        ),
                        TextSpan(text: '\nto ${provider.name}.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: careText(
                      13.5,
                      FontWeight.w400,
                      CareV2.muted,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: i < enteredDigits
                                    ? const Color(0xFF13A39B)
                                    : CareV2.outline,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: i < enteredDigits
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: CareV2.navy,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'This is a payment preview. No payment PIN has been set.',
                        ),
                      ),
                    ),
                    child: Text(
                      'Forgot PIN?',
                      style: careText(13, FontWeight.w500, CareV2.teal),
                    ),
                  ),
                  Text(
                    'Preview only · No money will move',
                    style: careText(11, FontWeight.w400, CareV2.muted),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                children: [
                  const Spacer(),
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['bio', '0', 'delete'],
                  ])
                    Row(
                      children: [
                        for (final key in row)
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: TextButton(
                                onPressed: key == 'delete'
                                    ? onDelete
                                    : key == 'bio'
                                    ? () => ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Biometric payment approval is unavailable in preview.',
                                              ),
                                            ),
                                          )
                                    : () => onDigit(key),
                                child: key == 'bio' || key == 'delete'
                                    ? SvgPicture.asset(
                                        '${CareV2.assets}${key == 'bio' ? 'pin-c232f.svg' : 'pin-69137.svg'}',
                                        width: 28,
                                        height: 28,
                                      )
                                    : Text(
                                        key,
                                        style: careText(
                                          26,
                                          FontWeight.w500,
                                          CareV2.navy,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CareV2ProcessingPreview extends StatefulWidget {
  const CareV2ProcessingPreview({
    required this.provider,
    required this.amountKobo,
    super.key,
  });
  final CareProvider provider;
  final int amountKobo;

  @override
  State<CareV2ProcessingPreview> createState() =>
      _CareV2ProcessingPreviewState();
}

class _CareV2ProcessingPreviewState extends State<CareV2ProcessingPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _rotation,
                child: SvgPicture.asset(
                  '${CareV2.assets}processing-502a2.svg',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sending your payment...',
                textAlign: TextAlign.center,
                style: careText(20, FontWeight.w700, CareV2.navy),
              ),
              const SizedBox(height: 10),
              Text(
                "Please don't close the app.\nThis will only take a moment.",
                textAlign: TextAlign.center,
                style: careText(
                  13.5,
                  FontWeight.w400,
                  CareV2.muted,
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                'UI preview only · No payment is being sent',
                style: careText(11, FontWeight.w400, CareV2.muted),
              ),
              const SizedBox(height: 28),
              Container(
                height: 98,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF9F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CareProviderAvatarV2(provider: widget.provider, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.provider.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: careText(15, FontWeight.w600, CareV2.navy),
                          ),
                          Text(
                            'Bank transfer',
                            style: careText(12, FontWeight.w400, CareV2.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      careMoney(widget.amountKobo),
                      style: careText(16, FontWeight.w700, CareV2.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CareV2SuccessPreview extends StatelessWidget {
  const CareV2SuccessPreview({
    required this.provider,
    required this.amountKobo,
    required this.onDone,
    super.key,
  });
  final CareProvider provider;
  final int amountKobo;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: onDone,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                      icon: SvgPicture.asset(
                        '${CareV2.assets}success-c81db.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 150,
                    width: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 43,
                          top: 13,
                          child: Transform.rotate(
                            angle: -math.pi / 4,
                            child: Container(
                              width: 5,
                              height: 22,
                              decoration: BoxDecoration(
                                color: CareV2.teal,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 51,
                          top: 8,
                          child: Transform.rotate(
                            angle: math.pi / 6,
                            child: Container(
                              width: 5,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8405F),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 36,
                          top: 78,
                          child: Transform.rotate(
                            angle: -math.pi / 9,
                            child: Container(
                              width: 14,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8405F),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 36,
                          top: 78,
                          child: Transform.rotate(
                            angle: math.pi / 9,
                            child: Container(
                              width: 14,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF13A39B),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 25,
                          child: Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: CareV2.teal,
                              shape: BoxShape.circle,
                            ),
                            child: SvgPicture.asset(
                              '${CareV2.assets}success-f0108.svg',
                              width: 40,
                              height: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Payment\nSuccessful!',
                    textAlign: TextAlign.center,
                    style: careText(22, FontWeight.w700, CareV2.navy),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Demo preview of ${careMoney(amountKobo)} to\n${provider.name}. No money was sent.',
                    textAlign: TextAlign.center,
                    style: careText(13, FontWeight.w400, CareV2.muted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: CareV2.outline),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CareProviderAvatarV2(provider: provider),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: careText(
                                      14,
                                      FontWeight.w600,
                                      CareV2.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF9F7),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SvgPicture.asset(
                                          '${CareV2.assets}success-67d63.svg',
                                          width: 14,
                                          height: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'HealthPocket Partner',
                                          style: careText(
                                            11,
                                            FontWeight.w400,
                                            CareV2.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _ReceiptRow('Amount', careMoney(amountKobo)),
                        _ReceiptRow('Date', _dateTime(DateTime.now())),
                        _ReceiptRow(
                          'Reference ID',
                          'Preview only',
                          icon: 'success-399f6.svg',
                        ),
                        const _ReceiptRow('Payment method', 'Bank Transfer'),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Status',
                                style: careText(
                                  12,
                                  FontWeight.w400,
                                  CareV2.muted,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F6EA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    '${CareV2.assets}success-cd110.svg',
                                    width: 12,
                                    height: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Preview',
                                    style: careText(
                                      11.5,
                                      FontWeight.w500,
                                      const Color(0xFF1E8E4E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                children: [
                  const Spacer(),
                  _SecondaryButton(
                    label: 'View Receipt',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A receipt will be available after a real payment. This was a UI preview.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CareV2Button(label: 'Done', onPressed: onDone),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _dateTime(DateTime date) =>
      '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class CareV2InsufficientBalance extends StatelessWidget {
  const CareV2InsufficientBalance({
    required this.amountKobo,
    required this.balanceKobo,
    required this.onBack,
    required this.onAddMoney,
    required this.onChangeAmount,
    super.key,
  });
  final int amountKobo;
  final int balanceKobo;
  final VoidCallback onBack;
  final VoidCallback onAddMoney;
  final VoidCallback onChangeAmount;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CareV2Back(
                      asset: 'insufficient-16de2.svg',
                      onTap: onBack,
                    ),
                  ),
                  const SizedBox(height: 52),
                  Image.asset(
                    '${CareV2.assets}insufficient-19263.png',
                    width: 185,
                    height: 176,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Insufficient Balance',
                    style: careText(20, FontWeight.w700, CareV2.navy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need ${careMoney(amountKobo - balanceKobo)} more\nto complete this payment.',
                    textAlign: TextAlign.center,
                    style: careText(
                      13.5,
                      FontWeight.w400,
                      CareV2.muted,
                    ).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF9F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment amount',
                          style: careText(12, FontWeight.w400, CareV2.muted),
                        ),
                        Text(
                          careMoney(amountKobo),
                          style: careText(22, FontWeight.w700, CareV2.navy),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your balance',
                          style: careText(12, FontWeight.w400, CareV2.muted),
                        ),
                        Text(
                          careMoney(balanceKobo),
                          style: careText(22, FontWeight.w700, CareV2.navy),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                children: [
                  const Spacer(),
                  CareV2Button(
                    label: 'Add Money',
                    arrowAsset: 'insufficient-ed152.svg',
                    onPressed: onAddMoney,
                  ),
                  const SizedBox(height: 12),
                  _SecondaryButton(
                    label: 'Choose a Different Amount',
                    onPressed: onChangeAmount,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.icon});
  final String label;
  final String value;
  final String? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: CareV2.outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: careText(12, FontWeight.w400, CareV2.muted),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: careText(13, FontWeight.w500, CareV2.navy),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: value)),
                  child: SvgPicture.asset(
                    '${CareV2.assets}$icon',
                    width: 16,
                    height: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.asset,
    required this.size,
    required this.iconSize,
  });
  final String asset;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: CareV2.mint, shape: BoxShape.circle),
    child: SvgPicture.asset(
      '${CareV2.assets}$asset',
      width: iconSize,
      height: iconSize,
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 46,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: CareV2.mint,
        foregroundColor: CareV2.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        elevation: 0,
      ),
      child: Text(label, style: careText(15, FontWeight.w600, CareV2.teal)),
    ),
  );
}
