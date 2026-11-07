import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/theme/app_ui_density.dart';

const _assetRoot = 'assets/dashboard/v2/states/';
const _teal = Color(0xFF0B7F7A);
const _navy = Color(0xFF0F1B4C);
const _muted = Color(0xFF5B6477);

Future<void> showPriceEstimateSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x800F1B4C),
      builder: (context) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: SizedBox(
          height: math.min(496, MediaQuery.sizeOf(context).height - 48),
          child: const _PriceEstimateSheet(),
        ),
      ),
    );

class _PriceEstimateSheet extends StatelessWidget {
  const _PriceEstimateSheet();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F6F3),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: SvgPicture.asset(
                    '${_assetRoot}estimate-calculator.svg',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'How we estimate prices',
                  textAlign: TextAlign.center,
                  style: _text(20, FontWeight.w700, _navy),
                ),
                const SizedBox(height: 8),
                Text(
                  'These figures help you see how far your balance can go.',
                  textAlign: TextAlign.center,
                  style: _text(
                    13.5,
                    FontWeight.w400,
                    _muted,
                  ).copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                const _EstimateReason(
                  'estimate-partner-rates.svg',
                  'Based on partner rates',
                  'We use typical prices from HealthPocket partners near you.',
                ),
                const SizedBox(height: 12),
                const _EstimateReason(
                  'estimate-provider-prices.svg',
                  'Providers set their own prices',
                  'The final cost can be higher or lower than the estimate.',
                ),
                const SizedBox(height: 12),
                const _EstimateReason(
                  'estimate-updated.svg',
                  'Kept up to date',
                  'We update estimates as partners share new prices.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Got it',
              style: _text(15, FontWeight.w600, Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EstimateReason extends StatelessWidget {
  const _EstimateReason(this.icon, this.title, this.description);
  final String icon;
  final String title;
  final String description;
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
        child: SvgPicture.asset('$_assetRoot$icon'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _text(14, FontWeight.w700, _navy)),
            const SizedBox(height: 2),
            Text(
              description,
              style: _text(
                12.5,
                FontWeight.w400,
                _muted,
              ).copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    ],
  );
}

TextStyle _text(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: AppUiDensity.font(size),
  fontWeight: weight,
  color: color,
);
