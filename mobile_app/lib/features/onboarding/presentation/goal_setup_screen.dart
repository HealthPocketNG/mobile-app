import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({super.key});

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _goalType = 'Emergency care';

  void _createGoal() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoute.dashboard.path,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'STEP 3 OF 3',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Start your first health goal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose what you’re preparing for. You can add more goals later.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              DropdownButtonFormField<String>(
                initialValue: _goalType,
                decoration: const InputDecoration(labelText: 'Goal type'),
                items: const [
                  DropdownMenuItem(value: 'Emergency care', child: Text('Emergency care')),
                  DropdownMenuItem(value: 'Routine care', child: Text('Routine care')),
                  DropdownMenuItem(value: 'Family care', child: Text('Family care')),
                  DropdownMenuItem(value: 'Other healthcare need', child: Text('Other healthcare need')),
                ],
                onChanged: (value) => setState(() => _goalType = value!),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                initialValue: _goalType,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Goal name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Give your goal a name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Target amount',
                  prefixText: '₦ ',
                  hintText: '100,000',
                ),
                validator: (value) => value == null || value.isEmpty || int.tryParse(value) == null
                    ? 'Enter a target amount'
                    : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(label: 'Create goal', onPressed: _createGoal),
            ],
          ),
        ),
      ),
    );
  }
}
