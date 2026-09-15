import 'package:flutter/material.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

class EditPersonalDetailsScreen extends StatefulWidget {
  const EditPersonalDetailsScreen({
    required this.profile,
    required this.emergencyContact,
    required this.onSave,
    super.key,
  });
  final UserProfile profile;
  final bool emergencyContact;
  final Future<void> Function(UserProfile) onSave;

  @override
  State<EditPersonalDetailsScreen> createState() =>
      _EditPersonalDetailsScreenState();
}

class _EditPersonalDetailsScreenState extends State<EditPersonalDetailsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _state;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  DateTime? _birth;
  String? _gender;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _address = TextEditingController(text: p.residentialAddress);
    _state = TextEditingController(text: p.stateOfResidence);
    _name = TextEditingController(text: p.nextOfKinName);
    _phone = TextEditingController(text: p.nextOfKinPhone);
    _birth = p.dateOfBirth;
    _gender = p.gender;
  }

  @override
  void dispose() {
    for (final controller in [_address, _state, _name, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!widget.emergencyContact && (_birth == null || _gender == null)) {
      setState(() => _error = 'Choose your date of birth and gender.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        widget.emergencyContact
            ? widget.profile.copyWith(
                nextOfKinName: _name.text.trim(),
                nextOfKinPhone: _phone.text.trim(),
              )
            : widget.profile.copyWith(
                dateOfBirth: _birth,
                gender: _gender,
                residentialAddress: _address.text.trim(),
                stateOfResidence: _state.text.trim(),
              ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not save your changes. Your draft is still here. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.emergencyContact
              ? 'Emergency contact'
              : 'Personal information',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.emergencyContact) ...[
              const Text(
                'Choose someone we can contact in an emergency. Make sure they agree to you sharing their details.',
              ),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Contact name'),
                validator: _required,
              ),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact phone number',
                ),
                validator: (value) =>
                    RegExp(r'^\+?[0-9 ()-]{7,25}$')
                        .hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid phone number',
              ),
            ] else ...[
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final first = DateTime(now.year - 100);
                        final last = DateTime(
                          now.year - 18,
                          now.month,
                          now.day,
                        );
                        final initial =
                            _birth != null &&
                                !_birth!.isBefore(first) &&
                                !_birth!.isAfter(last)
                            ? _birth!
                            : last;
                        final date = await showDatePicker(
                          context: context,
                          firstDate: first,
                          lastDate: last,
                          initialDate: initial,
                        );
                        if (mounted && date != null) {
                          setState(() => _birth = date);
                        }
                      },
                child: Text(
                  _birth == null
                      ? 'Choose date of birth'
                      : 'Date of birth: ${_birth!.day}/${_birth!.month}/${_birth!.year}',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue:
                    [
                      'male',
                      'female',
                      'other',
                      'prefer_not_to_say',
                    ].contains(_gender)
                    ? _gender
                    : null,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                  DropdownMenuItem(
                    value: 'prefer_not_to_say',
                    child: Text('Prefer not to say'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _gender = value),
                validator: _required,
              ),
              TextFormField(
                controller: _address,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Residential address',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: _state,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'State of residence',
                ),
                validator: _required,
              ),
            ],
            const SizedBox(height: 24),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            AppPrimaryButton(
              label: _saving ? 'Saving…' : 'Save changes',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
