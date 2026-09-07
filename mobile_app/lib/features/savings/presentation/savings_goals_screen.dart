import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_goal.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({required this.store, super.key});

  final SavingsStore store;

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  List<SavingsGoal> get _goals => widget.store.goals;
  List<SavingsContribution> get _contributions => widget.store.contributions;

  int get _totalSaved => widget.store.totalSaved;

  Future<void> _openGoalForm({SavingsGoal? goal}) async {
    final draft = await showModalBottomSheet<_GoalDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _GoalFormSheet(goal: goal),
    );
    if (draft == null) return;

    setState(() {
      if (goal == null) {
        widget.store.createGoal(
          title: draft.title,
          targetAmount: draft.targetAmount,
          frequency: draft.frequency,
        );
      } else {
        widget.store.updateGoal(
          goal,
          title: draft.title,
          targetAmount: draft.targetAmount,
          frequency: draft.frequency,
        );
      }
    });
  }

  Future<void> _addContribution(SavingsGoal goal) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ContributionSheet(goal: goal),
    );
    if (amount == null) return;

    setState(() {
      widget.store.recordContribution(goal, amount);
    });
  }

  void _toggleGoal(SavingsGoal goal) {
    setState(() {
      widget.store.toggleGoal(goal);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings goals'),
        actions: [
          IconButton(
            onPressed: _openGoalForm,
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create goal',
          ),
          const SizedBox(width: AppSpacing.sm),
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
          _SavingsSummary(totalSaved: _totalSaved, goalCount: _goals.length),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your goals',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _openGoalForm,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('New goal'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._goals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _GoalCard(
                goal: goal,
                onContribute: () => _addContribution(goal),
                onEdit: () => _openGoalForm(goal: goal),
                onToggle: () => _toggleGoal(goal),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Contribution history',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._contributions.map(
            (item) => _ContributionTile(contribution: item),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 1),
    );
  }
}

class _SavingsSummary extends StatelessWidget {
  const _SavingsSummary({required this.totalSaved, required this.goalCount});
  final int totalSaved;
  final int goalCount;

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
                  'Saved across your goals',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _naira(totalSaved),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$goalCount active health goals',
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
              Icons.savings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onContribute,
    required this.onEdit,
    required this.onToggle,
  });

  final SavingsGoal goal;
  final VoidCallback onContribute;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final paused = goal.status == SavingsGoalStatus.paused;
    final completed = goal.status == SavingsGoalStatus.completed;
    final progress = goal.progress.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      completed
                          ? 'Completed'
                          : paused
                          ? 'Paused'
                          : goal.frequency,
                      style: TextStyle(
                        color: paused
                            ? AppColors.secondary
                            : AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else {
                    onToggle();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                  if (!completed)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(paused ? 'Resume goal' : 'Pause goal'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                _naira(goal.currentAmount),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'of ${_naira(goal.targetAmount)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.outline,
            color: completed ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: paused || completed ? null : onContribute,
              icon: Icon(completed ? Icons.check_rounded : Icons.add_rounded),
              label: Text(
                completed
                    ? 'Goal completed'
                    : paused
                    ? 'Resume to add savings'
                    : 'Add savings',
              ),
            ),
          ),
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
      title: Text(
        contribution.goalTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(_dateLabel(contribution.createdAt)),
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

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({this.goal});
  final SavingsGoal? goal;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late String _frequency;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title);
    _targetController = TextEditingController(
      text: widget.goal?.targetAmount.toString(),
    );
    _frequency = widget.goal?.frequency ?? 'Monthly';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _GoalDraft(
        title: _titleController.text.trim(),
        targetAmount: int.parse(_targetController.text),
        frequency: _frequency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.goal == null ? 'Create health goal' : 'Edit health goal',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Goal name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a goal name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Target amount',
                  prefixText: '₦ ',
                ),
                validator: (value) =>
                    value == null ||
                        int.tryParse(value) == null ||
                        int.parse(value) < 1000
                    ? 'Enter at least ₦1,000'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Save frequency'),
                items: const [
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(
                    value: 'Whenever I can',
                    child: Text('Whenever I can'),
                  ),
                ],
                onChanged: (value) => setState(() => _frequency = value!),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: widget.goal == null ? 'Create goal' : 'Save changes',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet({required this.goal});
  final SavingsGoal goal;

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, int.parse(_amountController.text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
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
            Text(
              widget.goal.title,
              style: const TextStyle(color: AppColors.inkMuted),
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
              validator: (value) =>
                  value == null ||
                      int.tryParse(value) == null ||
                      int.parse(value) < 100
                  ? 'Enter at least ₦100'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Record mock contribution',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalDraft {
  const _GoalDraft({
    required this.title,
    required this.targetAmount,
    required this.frequency,
  });
  final String title;
  final int targetAmount;
  final String frequency;
}

String _naira(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '₦$value';
}

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
