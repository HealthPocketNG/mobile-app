import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/theme/app_ui_density.dart';
import 'package:healthpocket/features/activity/domain/unified_activity_ledger.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';

abstract final class ActivityV2 {
  static const assets = 'assets/activity/v2/';
  static const teal = Color(0xFF0B7F7A);
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const mint = Color(0xFFE4F6F3);
  static const soft = Color(0xFFF0F3F5);
  static const outline = Color(0xFFE8EDF0);
  static const pink = Color(0xFFE8405F);
}

TextStyle activityText(double size, FontWeight weight, Color color) =>
    TextStyle(
      fontFamily: 'Inter',
      fontSize: AppUiDensity.font(size),
      fontWeight: weight,
      color: color,
    );

String activityMoney(int amountKobo, {bool signed = false}) {
  final amount = amountKobo.abs() ~/ 100;
  final digits = amount.toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '${signed
      ? amountKobo < 0
            ? '- '
            : '+ '
      : ''}₦$grouped';
}

String activityDate(DateTime date, {bool time = false}) {
  final local = date.toLocal();
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ][local.month - 1];
  final result = '$month ${local.day}, ${local.year}';
  if (!time) return result;
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$result • $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}

String activityRelativeDate(DateTime? date) {
  if (date == null) return 'Development record';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;
  if (days == 0) {
    return 'Today, ${activityDate(date, time: true).split(' • ').last}';
  }
  if (days == 1) {
    return 'Yesterday, ${activityDate(date, time: true).split(' • ').last}';
  }
  return activityDate(date);
}

String activityCategoryLabel(ActivityCategory category) => switch (category) {
  ActivityCategory.all => 'All',
  ActivityCategory.savings => 'Savings',
  ActivityCategory.payments => 'Payments',
  ActivityCategory.family => 'Family Pocket',
  ActivityCategory.other => 'Other',
};

String activityRangeLabel(ActivityDateRange range) => switch (range) {
  ActivityDateRange.allTime => 'All Time',
  ActivityDateRange.last7Days => 'Last 7 Days',
  ActivityDateRange.last30Days => 'Last 30 Days',
  ActivityDateRange.custom => 'Custom Range',
};

class ActivityV2Item {
  const ActivityV2Item({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.amountKobo,
    required this.createdAt,
    required this.reference,
    required this.completed,
    required this.preview,
    this.location,
    this.paymentMethod,
    this.partner = false,
    this.iconAsset,
    this.detailLabel,
  });

  final String title, subtitle, reference;
  final ActivityCategory category;
  final int amountKobo;
  final DateTime? createdAt;
  final bool completed, preview, partner;
  final String? location, paymentMethod, iconAsset, detailLabel;

  bool get isPayment => category == ActivityCategory.payments;

  factory ActivityV2Item.fromLedger(ActivityLedgerItem item) {
    final record = item.record;
    return ActivityV2Item(
      title: item.category == ActivityCategory.family
          ? item.subtitle
          : item.title,
      subtitle: item.category == ActivityCategory.family
          ? 'Family Pocket Contribution'
          : (record.note ?? 'Savings Contribution'),
      category: item.category,
      amountKobo: record.amountKobo,
      createdAt: record.createdAt,
      reference: record.id,
      completed: record.status == ContributionStatus.recorded,
      preview: false,
      paymentMethod: record.moneyMovement
          ? 'HealthPocket Balance'
          : 'Development record',
      iconAsset: item.category == ActivityCategory.family
          ? '7b0f5.svg'
          : '220f3.svg',
      detailLabel: item.subtitle,
    );
  }
}

List<ActivityV2Item> activityPreviewItems(DateTime now) => [
  ActivityV2Item(
    title: 'Savings Contribution',
    subtitle: 'Savings Contribution',
    category: ActivityCategory.savings,
    amountKobo: 50000,
    createdAt: now.subtract(const Duration(hours: 2)),
    reference: 'DEMO-SAV-001',
    completed: true,
    preview: true,
    iconAsset: '220f3.svg',
    paymentMethod: 'HealthPocket Balance',
  ),
  ActivityV2Item(
    title: 'Lagoon Clinic',
    subtitle: 'Payment',
    category: ActivityCategory.payments,
    amountKobo: -250000,
    createdAt: now.subtract(const Duration(days: 1)),
    reference: 'DEMO-7283940',
    completed: true,
    preview: true,
    partner: true,
    location: 'Victoria Island, Lagos',
    paymentMethod: 'HealthPocket Balance',
    detailLabel: 'Clinic • Victoria Island, Lagos',
  ),
  ActivityV2Item(
    title: "Mum's Care",
    subtitle: 'Family Pocket Contribution',
    category: ActivityCategory.family,
    amountKobo: 100000,
    createdAt: now.subtract(const Duration(days: 3)),
    reference: 'DEMO-FAM-001',
    completed: true,
    preview: true,
    iconAsset: '7b0f5.svg',
    paymentMethod: 'HealthPocket Balance',
  ),
  ActivityV2Item(
    title: 'HealthPlus Pharmacy',
    subtitle: 'Payment',
    category: ActivityCategory.payments,
    amountKobo: -120000,
    createdAt: now.subtract(const Duration(days: 4)),
    reference: 'DEMO-7283941',
    completed: true,
    preview: true,
    location: 'Lagos, Nigeria',
    paymentMethod: 'HealthPocket Balance',
  ),
  ActivityV2Item(
    title: 'Weekly Savings',
    subtitle: 'Automatic Contribution',
    category: ActivityCategory.savings,
    amountKobo: 50000,
    createdAt: now.subtract(const Duration(days: 5)),
    reference: 'DEMO-SAV-002',
    completed: true,
    preview: true,
    iconAsset: '36d52.svg',
    paymentMethod: 'HealthPocket Balance',
  ),
];

class ActivityV2Back extends StatelessWidget {
  const ActivityV2Back({required this.onTap, super.key});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: SvgPicture.asset(
          '${ActivityV2.assets}9689a.svg',
          width: 20,
          height: 20,
        ),
      ),
    ),
  );
}

class ActivityV2Button extends StatelessWidget {
  const ActivityV2Button({
    required this.label,
    required this.onTap,
    this.secondary = false,
    this.asset,
    super.key,
  });
  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  final String? asset;
  @override
  Widget build(BuildContext context) => Material(
    color: onTap == null
        ? ActivityV2.soft
        : secondary
        ? ActivityV2.mint
        : ActivityV2.teal,
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: AppUiDensity.primaryButtonHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (asset != null && secondary) ...[
              SvgPicture.asset(
                '${ActivityV2.assets}$asset',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: activityText(
                15,
                FontWeight.w600,
                secondary ? ActivityV2.teal : Colors.white,
              ),
            ),
            if (asset != null && !secondary) ...[
              const SizedBox(width: 12),
              SvgPicture.asset(
                '${ActivityV2.assets}$asset',
                width: 20,
                height: 20,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ActivityV2DetailRow extends StatelessWidget {
  const ActivityV2DetailRow({
    required this.label,
    required this.value,
    this.last = false,
    this.trailing,
    super.key,
  });
  final String label, value;
  final bool last;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 42),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: ActivityV2.outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: activityText(12, FontWeight.w400, ActivityV2.muted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: activityText(13, FontWeight.w500, ActivityV2.navy),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    ),
  );
}

class ActivityV2StatusPill extends StatelessWidget {
  const ActivityV2StatusPill({required this.completed, super.key});
  final bool completed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: completed ? const Color(0xFFE3F6EA) : const Color(0xFFFFE8EC),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Text(
      completed ? 'Completed' : 'Reversed',
      style: activityText(
        11,
        FontWeight.w500,
        completed ? const Color(0xFF008A44) : ActivityV2.pink,
      ),
    ),
  );
}
