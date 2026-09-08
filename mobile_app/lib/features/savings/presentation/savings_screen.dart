import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({required this.store, super.key});

  final SavingsStore store;

  Future<void> _openPlanForm(BuildContext context) async {
    final draft = await showModalBottomSheet<_PlanDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PlanFormSheet(plan: store.plan),
    );
    if (draft == null) return;
    store.configurePlan(
      contributionAmount: draft.contributionAmount,
      frequency: draft.frequency,
      startDate: draft.startDate,
    );
  }

  Future<void> _addContribution(BuildContext context) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ContributionSheet(),
    );
    if (amount != null) store.recordContribution(amount);
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
              _SavingsSummary(balance: store.currentBalance),
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
                  onToggle: store.togglePlan,
                  onContribute: () => _addContribution(context),
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Contribution history',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (store.contributions.isEmpty)
                const _EmptyHistory()
              else
                ...store.contributions.map(
                  (item) => _ContributionTile(contribution: item),
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
  const _SavingsSummary({required this.balance});

  final int balance;

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
                  _naira(balance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  balance == 0
                      ? 'Your first contribution starts here'
                      : 'Built one contribution at a time',
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
    required this.onContribute,
  });

  final SavingsPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onContribute;

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
                      '${_naira(plan.contributionAmount)} ${plan.frequency.toLowerCase()}',
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
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContribute,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add savings'),
            ),
          ),
          if (paused) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Pausing stops future schedule instructions. You can still record a manual contribution.',
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

  final SavingsContribution contribution;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.south_west_rounded, color: AppColors.primary),
      ),
      title: const Text(
        'Health savings contribution',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${_dateLabel(contribution.createdAt)} • Demo record'),
      trailing: Text(
        '+${_naira(contribution.amount)}',
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
        'No contributions yet. Add your first savings record when you are ready.',
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
  late String _frequency;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.plan?.contributionAmount.toString(),
    );
    _frequency = widget.plan?.frequency ?? 'Monthly';
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
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Save frequency'),
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
              ],
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
              'Demo only—this does not move money from a bank account.',
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
              label: 'Record mock contribution',
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
  final String frequency;
  final DateTime startDate;
}

String? _amountValidator(String? value) =>
    value == null || int.tryParse(value) == null || int.parse(value) < 100
    ? 'Enter at least ₦100'
    : null;

String _naira(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '₦$value';
}

String _shortDate(DateTime date) =>
    '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

String _dateLabel(DateTime date) {
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
