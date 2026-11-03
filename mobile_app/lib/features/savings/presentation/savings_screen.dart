import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/presentation/savings_history_v2.dart';
import 'package:healthpocket/features/savings/presentation/savings_transfer_v2.dart';
import 'package:healthpocket/features/savings/presentation/savings_v2_screens.dart';

typedef SavingsPlanSaveCallback = Future<void> Function({
  required int contributionAmountKobo,
  required SavingsFrequency frequency,
  required DateTime startDate,
});

typedef DevelopmentContributionCallback = Future<void> Function({
  required int amountNaira,
  required String idempotencyKey,
});

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({
    required this.store,
    super.key,
    this.onSavePlan,
    this.onTogglePlan,
    this.developmentContributionsEnabled = false,
    this.onCreateContributionKey,
    this.onRecordDevelopmentContribution,
    this.onRetryContributions,
    this.designPreview = false,
  });

  final SavingsStore store;
  final SavingsPlanSaveCallback? onSavePlan;
  final Future<void> Function()? onTogglePlan;
  final bool developmentContributionsEnabled;
  final String Function()? onCreateContributionKey;
  final DevelopmentContributionCallback? onRecordDevelopmentContribution;
  final VoidCallback? onRetryContributions;
  final bool designPreview;

  Future<void> _openPlanForm(
    BuildContext context, {
    bool selectStartDateImmediately = false,
  }) async {
    final draft = await Navigator.of(context).push<SavingsPlanDraft>(
      MaterialPageRoute(
        builder: (_) => SavingsPlanEditorV2(
          plan: store.plan,
          selectStartDateImmediately: selectStartDateImmediately,
        ),
      ),
    );
    if (draft == null) return;
    try {
      final savePlan = onSavePlan;
      if (savePlan == null) {
        store.configurePlan(
          contributionAmountKobo: draft.amountKobo,
          frequency: draft.frequency,
          startDate: draft.startDate,
        );
      } else {
        await savePlan(
          contributionAmountKobo: draft.amountKobo,
          frequency: draft.frequency,
          startDate: draft.startDate,
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to save savings plan: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not save your plan. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _openPlanOptions(BuildContext context) async {
    final plan = store.plan;
    if (plan == null) {
      await _openPlanForm(context);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit savings plan'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Change start date'),
              onTap: () => Navigator.pop(sheetContext, 'date'),
            ),
            if (plan.status != SavingsPlanStatus.cancelled)
              ListTile(
                leading: Icon(
                  plan.status == SavingsPlanStatus.paused
                      ? Icons.play_arrow_outlined
                      : Icons.pause_outlined,
                ),
                title: Text(
                  plan.status == SavingsPlanStatus.paused
                      ? 'Resume plan'
                      : 'Pause plan',
                ),
                onTap: () => Navigator.pop(sheetContext, 'toggle'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await _openPlanForm(context);
      case 'date':
        await _openPlanForm(context, selectStartDateImmediately: true);
      case 'toggle':
        await _togglePlan(context);
    }
  }

  Future<void> _togglePlan(BuildContext context) async {
    try {
      final togglePlan = onTogglePlan;
      if (togglePlan == null) {
        store.togglePlan();
      } else {
        await togglePlan();
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to change savings plan status: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not update your plan. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _addContribution(BuildContext context) async {
    final amount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SavingsAddMoneyV2(
          designPreview: designPreview,
          onBankPreview: designPreview
              ? (amount) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SavingsTransferDetailsV2(amountNaira: amount),
                  ),
                )
              : null,
          canRecordDevelopmentContribution:
              developmentContributionsEnabled &&
              onCreateContributionKey != null &&
              onRecordDevelopmentContribution != null,
        ),
      ),
    );
    if (amount == null) return;
    if (!context.mounted) return;
    final createKey = onCreateContributionKey;
    final record = onRecordDevelopmentContribution;
    if (!developmentContributionsEnabled ||
        createKey == null ||
        record == null) {
      return;
    }
    final idempotencyKey = createKey();
    await _persistDevelopmentContribution(
      context,
      amountNaira: amount,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<void> _persistDevelopmentContribution(
    BuildContext context, {
    required int amountNaira,
    required String idempotencyKey,
  }) => _recordDevelopmentContribution(
    context,
    store: store,
    designPreview: designPreview,
    record: onRecordDevelopmentContribution!,
    amountNaira: amountNaira,
    idempotencyKey: idempotencyKey,
    onBack: () => Navigator.of(context).pop(),
    onActivity: () =>
        Navigator.pushReplacementNamed(context, AppRoute.activity.path),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        return SavingsOverviewV2(
          balanceKobo:
              (designPreview ? SavingsV2.previewBalanceKobo : 0) +
              store.developmentBalanceKobo,
          plan: store.plan,
          contributions: store.contributions,
          designPreview: designPreview,
          onEdit: () => _openPlanForm(context),
          onPlanOptions: () => _openPlanOptions(context),
          onAddMoney: () => _addContribution(context),
          onTogglePlan: () => _togglePlan(context),
          onHistory: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SavingsHistoryV2(
                store: store,
                designPreview: designPreview,
                onRetry: onRetryContributions,
              ),
            ),
          ),
        );
      },
    );
  }
}

class SavingsAddMoneyEntryScreen extends StatelessWidget {
  const SavingsAddMoneyEntryScreen({
    required this.store,
    required this.designPreview,
    required this.developmentContributionsEnabled,
    this.onCreateContributionKey,
    this.onRecordDevelopmentContribution,
    super.key,
  });

  final SavingsStore store;
  final bool designPreview;
  final bool developmentContributionsEnabled;
  final String Function()? onCreateContributionKey;
  final DevelopmentContributionCallback? onRecordDevelopmentContribution;

  @override
  Widget build(BuildContext context) {
    final createKey = onCreateContributionKey;
    final record = onRecordDevelopmentContribution;
    final canRecord =
        developmentContributionsEnabled && createKey != null && record != null;
    return SavingsAddMoneyV2(
      designPreview: designPreview,
      canRecordDevelopmentContribution: canRecord,
      onBankPreview: designPreview
          ? (amount) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SavingsTransferDetailsV2(amountNaira: amount),
              ),
            )
          : null,
      onRecordConfirmed: canRecord
          ? (amount) => _recordDevelopmentContribution(
              context,
              store: store,
              designPreview: designPreview,
              record: record,
              amountNaira: amount,
              idempotencyKey: createKey(),
              onBack: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoute.savings.path,
                (route) => route.settings.name == AppRoute.dashboard.path,
              ),
              onActivity: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoute.activity.path,
                (route) => route.settings.name == AppRoute.dashboard.path,
              ),
            )
          : null,
    );
  }
}

Future<void> _recordDevelopmentContribution(
  BuildContext context, {
  required SavingsStore store,
  required bool designPreview,
  required DevelopmentContributionCallback record,
  required int amountNaira,
  required String idempotencyKey,
  required VoidCallback onBack,
  required VoidCallback onActivity,
}) async {
  try {
    await record(amountNaira: amountNaira, idempotencyKey: idempotencyKey);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavingsMoneyAddedV2(
          amountNaira: amountNaira,
          newBalanceKobo:
              (designPreview ? SavingsV2.previewBalanceKobo : 0) +
              store.developmentBalanceKobo,
          developmentRecord: true,
          onBack: onBack,
          onActivity: onActivity,
        ),
      ),
    );
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Failed to save development contribution: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'We could not save this development record. No money moved.',
        ),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => unawaited(
            _recordDevelopmentContribution(
              context,
              store: store,
              designPreview: designPreview,
              record: record,
              amountNaira: amountNaira,
              idempotencyKey: idempotencyKey,
              onBack: onBack,
              onActivity: onActivity,
            ),
          ),
        ),
      ),
    );
  }
}
