import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/widgets/onboarding_step_header.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({required this.profileStore, super.key});

  final ProfileStore profileStore;

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _nextOfKinNameController;
  late final TextEditingController _nextOfKinPhoneController;
  DateTime? _dateOfBirth;
  String? _gender;
  String? _state;

  @override
  void initState() {
    super.initState();
    final profile = widget.profileStore.profile;
    _dateOfBirth = profile.dateOfBirth;
    _gender = profile.gender;
    _state = profile.stateOfResidence.isEmpty ? null : profile.stateOfResidence;
    _addressController = TextEditingController(
      text: profile.residentialAddress,
    );
    _nextOfKinNameController = TextEditingController(
      text: profile.nextOfKinName,
    );
    _nextOfKinPhoneController = TextEditingController(
      text: profile.nextOfKinPhone,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nextOfKinNameController.dispose();
    _nextOfKinPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18),
      initialDate: DateTime(now.year - 25),
    );
    if (date != null) setState(() => _dateOfBirth = date);
  }

  void _continue() {
    if (!_formKey.currentState!.validate() ||
        _dateOfBirth == null ||
        _gender == null ||
        _state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the required details to continue.'),
        ),
      );
      return;
    }
    widget.profileStore.updatePersonalInformation(
      dateOfBirth: _dateOfBirth!,
      gender: _gender!,
      residentialAddress: _addressController.text.trim(),
      stateOfResidence: _state!,
      nextOfKinName: _nextOfKinNameController.text.trim(),
      nextOfKinPhone: _nextOfKinPhoneController.text.trim(),
    );
    Navigator.pushNamed(context, AppRoute.savingsPlanSetup.path);
  }

  @override
  Widget build(BuildContext context) {
    final date = _dateOfBirth;
    final dateText = date == null
        ? 'Select your date of birth'
        : '${date.day} ${_monthName(date.month)} ${date.year}';

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
                title: 'Personal details',
                step: 1,
                total: 2,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SelectionField(
                icon: Icons.calendar_today_outlined,
                label: 'Date of birth',
                value: dateText,
                onTap: _selectDate,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(
                    value: 'prefer_not_to_say',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Residential address',
                  hintText: 'House number and street',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _state,
                decoration: const InputDecoration(
                  labelText: 'State of residence',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'Lagos', child: Text('Lagos')),
                  DropdownMenuItem(value: 'Abuja', child: Text('Abuja (FCT)')),
                  DropdownMenuItem(value: 'Ogun', child: Text('Ogun')),
                  DropdownMenuItem(value: 'Oyo', child: Text('Oyo')),
                  DropdownMenuItem(value: 'Rivers', child: Text('Rivers')),
                  DropdownMenuItem(value: 'Other', child: Text('Other state')),
                ],
                onChanged: (value) => setState(() => _state = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Next of kin / Emergency contact',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _nextOfKinNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _nextOfKinPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+234 800 000 0000',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(label: 'Continue', onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
