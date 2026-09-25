import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';

enum HealthPocketStateKind {
  loading,
  empty,
  error,
  offline,
  noResults,
  success,
}

class HealthPocketStateView extends StatelessWidget {
  const HealthPocketStateView({
    required this.kind,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.showLogo = false,
    this.compact = false,
    super.key,
  });

  final HealthPocketStateKind kind;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool showLogo;
  final bool compact;

  IconData get _icon => switch (kind) {
    HealthPocketStateKind.loading => Icons.hourglass_top_rounded,
    HealthPocketStateKind.empty => Icons.receipt_long_outlined,
    HealthPocketStateKind.error => Icons.error_outline_rounded,
    HealthPocketStateKind.offline => Icons.wifi_off_rounded,
    HealthPocketStateKind.noResults => Icons.location_searching_rounded,
    HealthPocketStateKind.success => Icons.check_rounded,
  };

  Color get _iconColor => switch (kind) {
    HealthPocketStateKind.error => AppColors.error,
    HealthPocketStateKind.offline => AppColors.inkMuted,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: compact ? AppSpacing.md : AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            const AppBrandLogo(centered: true),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (!compact) ...[
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: kind == HealthPocketStateKind.error
                    ? const Color(0xFFFFEEEC)
                    : AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: kind == HealthPocketStateKind.loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Icon(_icon, color: _iconColor, size: 42),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.inkMuted, height: 1.45),
          ),
          if (primaryActionLabel != null && onPrimaryAction != null) ...[
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
            AppPrimaryButton(
              label: primaryActionLabel!,
              onPressed: onPrimaryAction,
            ),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null)
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
        ],
      ),
    ),
  );
}

class InsufficientBalanceView extends StatelessWidget {
  const InsufficientBalanceView({
    required this.paymentAmountKobo,
    required this.availableBalanceKobo,
    required this.onChooseDifferentAmount,
    this.onAddMoney,
    super.key,
  });

  final int paymentAmountKobo;
  final int availableBalanceKobo;
  final VoidCallback onChooseDifferentAmount;
  final VoidCallback? onAddMoney;

  @override
  Widget build(BuildContext context) {
    final shortfall = (paymentAmountKobo - availableBalanceKobo).clamp(
      0,
      paymentAmountKobo,
    );
    return HealthPocketStateView(
      kind: HealthPocketStateKind.error,
      title: 'Insufficient Balance',
      message:
          'You need ${_formatKobo(shortfall)} more to complete this payment.\n\nPayment amount: ${_formatKobo(paymentAmountKobo)}\nYour balance: ${_formatKobo(availableBalanceKobo)}',
      primaryActionLabel: onAddMoney == null
          ? 'Choose a Different Amount'
          : 'Add Money  →',
      onPrimaryAction: onAddMoney ?? onChooseDifferentAmount,
      secondaryActionLabel: onAddMoney == null
          ? null
          : 'Choose a Different Amount',
      onSecondaryAction: onAddMoney == null ? null : onChooseDifferentAmount,
    );
  }
}

String _formatKobo(int kobo) {
  final naira = kobo ~/ 100;
  return '₦${naira.toString().replaceAllMapped(RegExp(r'\\B(?=(\\d{3})+(?!\\d))'), (match) => ',')}';
}
