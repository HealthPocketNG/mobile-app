import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/widgets/onboarding_step_header.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

class SavingsPlanSetupScreen extends StatefulWidget {
  const SavingsPlanSetupScreen({
    required this.savingsStore,
    required this.onCompleted,
    super.key,
  });

  final SavingsStore savingsStore;
  final Future<void> Function() onCompleted;

  @override
  State<SavingsPlanSetupScreen> createState() => _SavingsPlanSetupScreenState();
}

class _SavingsPlanSetupScreenState extends State<SavingsPlanSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late SavingsFrequency _frequency;
  late DateTime _startDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.savingsStore.plan;
    _amountController = TextEditingController(
      text: (plan?.contributionAmount ?? 5000).toString(),
    );
    _frequency = plan?.frequency ?? SavingsFrequency.monthly;
    _startDate = plan?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _startDate,
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _createPlan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    widget.savingsStore.saveOnboardingPlan(
      contributionAmount: int.parse(_amountController.text),
      frequency: _frequency,
      startDate: _startDate,
    );
    try {
      await widget.onCompleted();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoute.createPin.path,
        (route) => false,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to persist onboarding: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not save your setup. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              const OnboardingStepHeader(
                title: 'Set up savings',
                step: 2,
                total: 2,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: AppColors.secondary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save consistently for your health.',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose an amount and schedule that works for you.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Amount to save each time',
                  prefixIcon: Icon(Icons.savings_outlined),
                  prefixText: '₦ ',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    value == null ||
                        int.tryParse(value) == null ||
                        int.parse(value) < 100
                    ? 'Enter an amount of at least ₦100'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<SavingsFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Save frequency',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
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
              _DateTile(date: _startDate, onTap: _selectStartDate),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You’ll save',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                          Text(
                            '₦${_formatAmount(_amountController.text)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_frequency.label}, starting ${_shortDate(_startDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: 'Create savings plan',
                onPressed: _createPlan,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '0';
    return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  String _shortDate(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Material(
      color: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.event_outlined, color: AppColors.primaryDark),
        title: const Text('Start date'),
        subtitle: Text('${date.day} ${months[date.month - 1]} ${date.year}'),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
