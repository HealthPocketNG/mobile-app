import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _MoneyAddedSuccessScreen(
            amountNaira: amountNaira,
            store: store,
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
          appBar: AppBar(
            title: const Text('Savings'),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.history),
                tooltip: 'Savings history',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SavingsHistoryScreen(store: store),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              const Text(
                'Your health fund at a glance.',
                style: TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
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
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SavingsHistoryScreen(store: store),
                  ),
                ),
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                iconAlignment: IconAlignment.end,
                label: const Text('View savings history'),
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
      height: 132,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF08A69B), AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total Savings', style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 4),
        Text(_formatKobo(balanceKobo), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const Spacer(),
        const Text('Keep going 💪', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
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
      text: (widget.plan?.contributionAmount ?? 500).toString(),
    );
    _frequency = widget.plan?.frequency ?? SavingsFrequency.weekly;
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
              'Set Your Savings Plan',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Choose how often you want to save and set your amount.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...SavingsFrequency.values.map((frequency) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanFrequencyTile(
                frequency: frequency,
                amount: int.tryParse(_amountController.text) ?? 500,
                selected: _frequency == frequency,
                onTap: () => setState(() => _frequency = frequency),
              ),
            )),
            const SizedBox(height: AppSpacing.sm),
            const Text('Custom Amount', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(prefixText: '₦ ', hintText: '500'),
              validator: _amountValidator,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            const Text('You can increase this amount anytime.', style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
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
            AppPrimaryButton(label: 'Save Plan  →', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _PlanFrequencyTile extends StatelessWidget {
  const _PlanFrequencyTile({required this.frequency, required this.amount, required this.selected, required this.onTap});
  final SavingsFrequency frequency;
  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primarySoft : AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.primary : AppColors.outline)),
        child: Row(children: [
          Icon(frequency == SavingsFrequency.daily ? LucideIcons.sun : frequency == SavingsFrequency.weekly ? LucideIcons.calendarDays : LucideIcons.calendarRange, color: selected ? AppColors.primary : AppColors.inkMuted),
          const SizedBox(width: 14),
          Expanded(child: Text(frequency.label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(_formatNaira(amount), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Icon(selected ? LucideIcons.circleDot : LucideIcons.circle, color: selected ? AppColors.primary : AppColors.inkMuted),
        ]),
      ),
    ),
  );
}

class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet();

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '500');
  int? _selectedAmount = 500;

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
              'Add Money',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Choose or enter an amount to add to your HealthPocket.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [500, 1000, 2000, 5000, 10000].map((amount) => _AmountPreset(
                amount: amount,
                selected: _selectedAmount == amount,
                onTap: () => setState(() { _selectedAmount = amount; _amountController.text = amount.toString(); }),
              )).toList()..add(_AmountPreset(label: 'Other', selected: _selectedAmount == null, onTap: () => setState(() => _selectedAmount = null))),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              tileColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              leading: CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(LucideIcons.landmark, color: AppColors.primary)),
              title: Text('Pay with Bank', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Secure payment via your bank app'),
              trailing: Icon(LucideIcons.chevronRight),
            ),
            const SizedBox(height: AppSpacing.md),
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

class _AmountPreset extends StatelessWidget {
  const _AmountPreset({this.amount, this.label, required this.selected, required this.onTap});
  final int? amount;
  final String? label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primarySoft : AppColors.surfaceMuted,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppColors.primary : Colors.transparent)),
        child: Text(label ?? _formatNaira(amount!), style: TextStyle(fontWeight: FontWeight.w800, color: selected ? AppColors.primaryDark : AppColors.primary)),
      ),
    ),
  );
}

class _MoneyAddedSuccessScreen extends StatelessWidget {
  const _MoneyAddedSuccessScreen({required this.amountNaira, required this.store});
  final int amountNaira;
  final SavingsStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Align(alignment: Alignment.topLeft, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x))),
        const SizedBox(height: 18),
        const CircleAvatar(radius: 48, backgroundColor: AppColors.primary, child: Icon(LucideIcons.check, color: Colors.white, size: 50)),
        const SizedBox(height: 24),
        Text('Money Added!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_formatNaira(amountNaira), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${_formatNaira(amountNaira)} has been added to your HealthPocket savings.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        const Text('Development record — no money moved.', style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 24),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('New Balance', style: TextStyle(color: AppColors.inkMuted)),
          Text(_formatKobo(store.developmentBalanceKobo), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
        ])),
        const SizedBox(height: 14),
        const ListTile(leading: CircleAvatar(backgroundColor: Color(0xFFFFEEF1), child: Text('🔥')), title: Text('You’re doing great!', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Every contribution brings you closer to a healthier tomorrow.')),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Savings'))),
        TextButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoute.activity.path), child: const Text('View Activity')),
      ]),
    ))),
  );
}

enum _HistoryFilter { all, addedMoney, planSavings, failed }

class _SavingsHistoryScreen extends StatefulWidget {
  const _SavingsHistoryScreen({required this.store});
  final SavingsStore store;

  @override
  State<_SavingsHistoryScreen> createState() => _SavingsHistoryScreenState();
}

class _SavingsHistoryScreenState extends State<_SavingsHistoryScreen> {
  var _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, child) {
          final records = _filteredRecords(widget.store.contributions);
          final groups = _groupByMonth(records);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.chevronLeft)),
                const SizedBox(width: 4),
                Expanded(child: Text('Savings History', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Download statement',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statements will be available soon.'))),
                  icon: const Icon(LucideIcons.download, color: AppColors.primaryDark),
                ),
              ]),
              const Padding(
                padding: EdgeInsets.only(left: 52),
                child: Text('A record of your contributions.', style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _HistoryFilter.values.map((filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _HistoryFilterChip(
                    label: _historyFilterLabel(filter),
                    selected: _filter == filter,
                    onTap: () => setState(() => _filter = filter),
                  ),
                )).toList()),
              ),
              const SizedBox(height: 22),
              if (records.isEmpty)
                const _EmptyHistory()
              else
                for (final group in groups.entries) ...[
                  Text(group.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  ...group.value.map((record) => _SavingsHistoryTile(record: record)),
                  const SizedBox(height: 18),
                ],
            ],
          );
        },
      ),
    ),
  );

  List<ContributionRecord> _filteredRecords(List<ContributionRecord> records) => switch (_filter) {
    _HistoryFilter.all || _HistoryFilter.addedMoney => records,
    _HistoryFilter.planSavings || _HistoryFilter.failed => const [],
  };
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.surfaceMuted,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.ink, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

class _SavingsHistoryTile extends StatelessWidget {
  const _SavingsHistoryTile({required this.record});
  final ContributionRecord record;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outline))),
    child: Row(children: [
      const CircleAvatar(radius: 20, backgroundColor: AppColors.primarySoft, child: Icon(LucideIcons.piggyBank, color: AppColors.primary, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Added Money', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(_historyDate(context, record.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ])),
      Text('+${_formatKobo(record.amountKobo)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
    ]),
  );
}

String _historyFilterLabel(_HistoryFilter filter) => switch (filter) {
  _HistoryFilter.all => 'All',
  _HistoryFilter.addedMoney => 'Added Money',
  _HistoryFilter.planSavings => 'Plan Savings',
  _HistoryFilter.failed => 'Failed',
};

Map<String, List<ContributionRecord>> _groupByMonth(List<ContributionRecord> records) {
  final groups = <String, List<ContributionRecord>>{};
  for (final record in records) {
    final date = record.createdAt;
    final label = date == null ? 'Recent' : '${_monthName(date.month)} ${date.year}';
    groups.putIfAbsent(label, () => []).add(record);
  }
  return groups;
}

String _monthName(int month) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month - 1];

String _historyDate(BuildContext context, DateTime? date) {
  if (date == null) return 'Development record • No money moved';
  return '${_monthName(date.month).substring(0, 3)} ${date.day}, ${date.year} • ${TimeOfDay.fromDateTime(date).format(context)}';
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
    value == null || int.tryParse(value) == null || int.parse(value) < 500
    ? 'Enter at least ₦500'
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

