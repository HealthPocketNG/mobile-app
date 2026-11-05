import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';

abstract final class CareV2 {
  static const assets = 'assets/care/v2/';
  static const teal = Color(0xFF0B7F7A);
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const mint = Color(0xFFE4F6F3);
  static const soft = Color(0xFFF0F3F5);
  static const outline = Color(0xFFE8EDF0);
}

TextStyle careText(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

String careType(CareProviderType type) => switch (type) {
  CareProviderType.clinic => 'Clinic',
  CareProviderType.hospital => 'Hospital',
  CareProviderType.pharmacy => 'Pharmacy',
  CareProviderType.diagnostics => 'Diagnostics',
  CareProviderType.other => 'Healthcare provider',
};

String careMoney(int amountKobo) {
  final amount = amountKobo ~/ 100;
  final digits = amount.toString();
  final reversed = digits.split('').reversed.toList();
  final chunks = <String>[];
  for (var index = 0; index < reversed.length; index += 3) {
    chunks.add(reversed.skip(index).take(3).toList().reversed.join());
  }
  return '₦ ${chunks.reversed.join(',')}';
}

class CareV2Back extends StatelessWidget {
  const CareV2Back({required this.asset, required this.onTap, super.key});
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onTap,
    alignment: Alignment.centerLeft,
    padding: EdgeInsets.zero,
    icon: SvgPicture.asset('${CareV2.assets}$asset', width: 20, height: 20),
  );
}

class CareV2Button extends StatelessWidget {
  const CareV2Button({
    required this.label,
    required this.onPressed,
    this.arrowAsset,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? arrowAsset;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: CareV2.teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: CareV2.outline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: careText(15, FontWeight.w600, Colors.white),
              ),
            ),
          ),
          if (arrowAsset != null) ...[
            const SizedBox(width: 10),
            SvgPicture.asset(
              '${CareV2.assets}$arrowAsset',
              width: 20,
              height: 20,
            ),
          ],
        ],
      ),
    ),
  );
}

class CareProviderAvatarV2 extends StatelessWidget {
  const CareProviderAvatarV2({
    required this.provider,
    this.size = 44,
    super.key,
  });
  final CareProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = provider.name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    final color = switch (provider.type) {
      CareProviderType.pharmacy => const Color(0xFFFFEBC8),
      CareProviderType.hospital => const Color(0xFFD9E8FF),
      CareProviderType.clinic => const Color(0xFFCDEFEA),
      CareProviderType.diagnostics => const Color(0xFFE6DEFB),
      CareProviderType.other => CareV2.mint,
    };
    final ink = switch (provider.type) {
      CareProviderType.pharmacy => const Color(0xFF9A6200),
      CareProviderType.hospital => const Color(0xFF2B5BD7),
      CareProviderType.clinic => CareV2.teal,
      CareProviderType.diagnostics => const Color(0xFF5B3FC4),
      CareProviderType.other => CareV2.teal,
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: careText(size >= 60 ? 20 : 13, FontWeight.w700, ink),
      ),
    );
  }
}

class CarePartnerBadgeV2 extends StatelessWidget {
  const CarePartnerBadgeV2({
    required this.provider,
    required this.iconAsset,
    this.short = false,
    super.key,
  });
  final CareProvider provider;
  final String iconAsset;
  final bool short;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: provider.isPartner ? const Color(0xFFEEF9F7) : CareV2.soft,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.isPartner) ...[
          SvgPicture.asset(
            '${CareV2.assets}$iconAsset',
            width: switch (iconAsset) {
              'find-a9c44.svg' => 12.25,
              'find-a2092.svg' => 12.73,
              'transfer-1f060.svg' => 13.31,
              'review-e0188.svg' => 13.33,
              _ => 14,
            },
            height: 14,
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              provider.isPartner
                  ? (short ? 'HP Partner' : 'HealthPocket Partner')
                  : 'Not a partner',
              maxLines: 1,
              style: careText(
                short ? 10.5 : 11,
                FontWeight.w400,
                provider.isPartner ? CareV2.teal : CareV2.muted,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class CareProviderSummaryV2 extends StatelessWidget {
  const CareProviderSummaryV2({
    required this.provider,
    required this.badgeAsset,
    this.highlighted = false,
    super.key,
  });
  final CareProvider provider;
  final String badgeAsset;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: highlighted ? const EdgeInsets.all(14) : EdgeInsets.zero,
    decoration: highlighted
        ? BoxDecoration(
            color: const Color(0xFFEEF9F7),
            borderRadius: BorderRadius.circular(14),
          )
        : null,
    child: Row(
      children: [
        CareProviderAvatarV2(provider: provider, size: highlighted ? 48 : 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: careText(
                  highlighted ? 14 : 16,
                  FontWeight.w700,
                  CareV2.navy,
                ),
              ),
              if (!highlighted) ...[
                const SizedBox(height: 3),
                Text(
                  '${careType(provider.type)} · ${provider.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: careText(12, FontWeight.w400, CareV2.muted),
                ),
              ],
              const SizedBox(height: 4),
              CarePartnerBadgeV2(provider: provider, iconAsset: badgeAsset),
              if (highlighted) ...[
                const SizedBox(height: 4),
                Text(
                  '${provider.city}, ${provider.state}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: careText(12, FontWeight.w400, CareV2.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
