import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

typedef SavingsPlanSaveCallback = Future<void> Function({
  required int contributionAmount,
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
  });

  final SavingsStore store;
  final SavingsPlanSaveCallback? onSavePlan;
  final Future<void> Function()? onTogglePlan;
  final bool developmentContributionsEnabled;
  final String Function()? onCreateContributionKey;
  final DevelopmentContributionCallback? onRecordDevelopmentContribution;
  final VoidCallback? onRetryContributions;

  Future<void> _openPlanForm(BuildContext context) async {
    final draft = await showModalBottomSheet<_PlanDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PlanFormSheet(plan: store.plan),
    );
    if (draft == null) return;
    try {
      final savePlan = onSavePlan;
      if (savePlan == null) {
        store.configurePlan(
          contributionAmount: draft.contributionAmount,
          frequency: draft.frequency,
          startDate: draft.startDate,
        );
      } else {
        await savePlan(
          contributionAmount: draft.contributionAmount,
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
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ContributionSheet(),
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
  }) async {
    try {
      await onRecordDevelopmentContribution!(
        amountNaira: amountNaira,
        idempotencyKey: idempotencyKey,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Development record saved — no money moved.'),
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
              _persistDevelopmentContribution(
                context,
                amountNaira: amountNaira,
                idempotencyKey: idempotencyKey,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final plan = store.plan;
        return Scaffold(
          appBar: AppBar(title: const Text('Savings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _SavingsSummary(balanceKobo: store.developmentBalanceKobo),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Your savings plan',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (plan == null)
                _NoPlanCard(onCreate: () => _openPlanForm(context))
              else
                _PlanCard(
                  plan: plan,
                  onEdit: () => _openPlanForm(context),
                  onToggle: () => _togglePlan(context),
                  onContribute: developmentContributionsEnabled
                      ? () => _addContribution(context)
                      : null,
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Contribution history',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ContributionHistory(
                store: store,
                developmentContributionsEnabled:
                    developmentContributionsEnabled,
                onRetry: onRetryContributions,
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomNavigation(currentIndex: 1),
        );
      },
    );
  }
}

class _SavingsSummary extends StatelessWidget {
  const _SavingsSummary({required this.balanceKobo});

  final int balanceKobo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your health balance',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatKobo(balanceKobo),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  balanceKobo == 0
                      ? 'Your first contribution starts here'
                      : 'Development balance — no money moved',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onToggle,
    this.onContribute,
  });

  final SavingsPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback? onContribute;

  @override
  Widget build(BuildContext context) {
    final paused = plan.status == SavingsPlanStatus.paused;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.savings_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatNaira(plan.contributionAmount)} ${plan.frequency.label.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      paused ? 'Plan paused' : 'Plan active',
                      style: TextStyle(
                        color: paused ? AppColors.secondary : AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? onEdit() : onToggle(),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit savings plan'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(paused ? 'Resume plan' : 'Pause plan'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 19,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Started ${_shortDate(plan.startDate)}',
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          if (onContribute != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContribute,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add development record'),
              ),
            ),
          ],
          if (paused) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Pausing stops future schedule instructions. Development records remain available in DEV.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.savings_outlined,
            size: 42,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Choose a comfortable amount and schedule to begin building your health balance.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(label: 'Set up savings plan', onPressed: onCreate),
        ],
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({required this.contribution});

  final ContributionRecord contribution;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.south_west_rounded, color: AppColors.primary),
      ),
      title: const Text(
        'Simulated savings contribution',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_dateLabel(contribution.createdAt)} • Development record — no money moved',
      ),
      trailing: Text(
        '+${_formatKobo(contribution.amountKobo)}',
        style: const TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No development records yet. Add one to test your savings experience. No money will move.',
      ),
    );
  }
}

class _ContributionHistory extends StatelessWidget {
  const _ContributionHistory({
    required this.store,
    required this.developmentContributionsEnabled,
    this.onRetry,
  });

  final SavingsStore store;
  final bool developmentContributionsEnabled;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!developmentContributionsEnabled) {
      return const Text(
        'Simulated contribution controls are unavailable in production builds.',
        style: TextStyle(color: AppColors.inkMuted),
      );
    }
    return switch (store.contributionLoadStatus) {
      ContributionLoadStatus.loading => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      ContributionLoadStatus.failure => _ContributionLoadFailure(
        onRetry: onRetry,
      ),
      ContributionLoadStatus.ready when store.contributions.isEmpty =>
        const _EmptyHistory(),
      ContributionLoadStatus.ready => Column(
        children: store.contributions
            .map((item) => _ContributionTile(contribution: item))
            .toList(growable: false),
      ),
      ContributionLoadStatus.idle => const Text(
        'Development records will load after your savings setup is restored.',
        style: TextStyle(color: AppColors.inkMuted),
      ),
    };
  }
}

class _ContributionLoadFailure extends StatelessWidget {
  const _ContributionLoadFailure({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'We could not load your development records. No balance has been assumed.',
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

class _PlanFormSheet extends StatefulWidget {
  const _PlanFormSheet({this.plan});

  final SavingsPlan? plan;

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late SavingsFrequency _frequency;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.plan?.contributionAmount.toString(),
    );
    _frequency = widget.plan?.frequency ?? SavingsFrequency.monthly;
    _startDate = widget.plan?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year - 1),
      lastDate: today.add(const Duration(days: 730)),
      initialDate: _startDate,
    );
    if (date != null) setState(() => _startDate = date);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PlanDraft(
        contributionAmount: int.parse(_amountController.text),
        frequency: _frequency,
        startDate: _startDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plan == null ? 'Set up savings plan' : 'Edit savings plan',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This records your preference only. No bank debit will occur.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Amount to save each time',
                prefixText: '₦ ',
              ),
              validator: _amountValidator,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<SavingsFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Save frequency'),
              items: SavingsFrequency.values
                  .map(
                    (frequency) => DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _frequency = value!),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Plan start date'),
              subtitle: Text(_shortDate(_startDate)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _selectStartDate,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(label: 'Save plan', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet();

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add savings',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Development record — no money moved from a bank account.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Contribution amount',
                prefixText: '₦ ',
              ),
              validator: _amountValidator,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Record development contribution',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context, int.parse(_amountController.text));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: child,
    );
  }
}

class _PlanDraft {
  const _PlanDraft({
    required this.contributionAmount,
    required this.frequency,
    required this.startDate,
  });

  final int contributionAmount;
  final SavingsFrequency frequency;
  final DateTime startDate;
}

String? _amountValidator(String? value) =>
    value == null || int.tryParse(value) == null || int.parse(value) < 100
    ? 'Enter at least ₦100'
    : int.parse(value) > 1000000000
    ? 'Enter no more than ₦1,000,000,000'
    : null;

String _formatNaira(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '₦$value';
}

String _formatKobo(int amountKobo) {
  final naira = amountKobo ~/ 100;
  final kobo = amountKobo.remainder(100).abs();
  final whole = _formatNaira(naira);
  return kobo == 0 ? whole : '$whole.${kobo.toString().padLeft(2, '0')}';
}

String _shortDate(DateTime date) =>
    '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

String _dateLabel(DateTime? date) {
  if (date == null) return 'Saving…';
  final now = DateTime.now();
  final difference = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '$difference days ago';
}
