import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/auth/presentation/auth_v2_widgets.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({
    required this.profileStore,
    required this.onCompleted,
    super.key,
  });
  final ProfileStore profileStore;
  final Future<void> Function() onCompleted;
  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _name = TextEditingController();
  DateTime? _birth;
  String? _gender;
  String? _state;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profileStore.profile;
    _name.text = p.fullName;
    _birth = p.dateOfBirth;
    _gender = p.gender;
    _state = p.stateOfResidence.isEmpty ? null : p.stateOfResidence;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18),
    );
    if (date != null) setState(() => _birth = date);
  }

  Future<void> _continue() async {
    if (_name.text.trim().length < 2 ||
        _birth == null ||
        _gender == null ||
        _state == null) {
      setState(() => _error = 'Complete the required details to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final profile = widget.profileStore.profile;
    widget.profileStore.updateAccount(
      fullName: _name.text.trim(),
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      stateOfResidence: _state!,
    );
    widget.profileStore.updatePersonalInformation(
      dateOfBirth: _birth!,
      gender: _gender!,
      residentialAddress: profile.residentialAddress,
      stateOfResidence: _state!,
      nextOfKinName: profile.nextOfKinName,
      nextOfKinPhone: profile.nextOfKinPhone,
    );
    try {
      await widget.onCompleted();
      if (mounted) Navigator.pushNamed(context, AppRoute.createPin.path);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not save your details. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthday = _birth;
    final birthLabel = birthday == null
        ? 'Select date of birth'
        : '${_month(birthday.month)} ${birthday.day}, ${birthday.year}';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            const AuthV2Back(),
            const SizedBox(height: 18),
            const AuthV2Heading(
              'Tell us a bit about you',
              'This helps us personalize\nyour experience.',
            ),
            const SizedBox(height: 26),
            Center(
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCDEFEA),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset('${AuthV2.assets}77fb1.svg'),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AuthV2.navy,
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset('${AuthV2.assets}ecc31.svg'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AuthV2Field(
              label: 'Full name',
              controller: _name,
              hint: 'David Okafor',
            ),
            const SizedBox(height: 16),
            _field('Date of birth', birthLabel, _pickDate, '1e5a5.svg'),
            const SizedBox(height: 16),
            Text('Gender', style: AuthV2.label),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: _decoration(),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(
                  value: 'prefer_not_to_say',
                  child: Text('Prefer not to say'),
                ),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),
            Text('Location', style: AuthV2.label),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: _state,
              decoration: _decoration(),
              hint: const Text('Select location'),
              items: const [
                DropdownMenuItem(value: 'Lagos', child: Text('Lagos, Nigeria')),
                DropdownMenuItem(value: 'Abuja', child: Text('Abuja, Nigeria')),
                DropdownMenuItem(value: 'Ogun', child: Text('Ogun, Nigeria')),
                DropdownMenuItem(value: 'Oyo', child: Text('Oyo, Nigeria')),
                DropdownMenuItem(
                  value: 'Rivers',
                  child: Text('Rivers, Nigeria'),
                ),
                DropdownMenuItem(value: 'Other', child: Text('Other, Nigeria')),
              ],
              onChanged: (v) => setState(() => _state = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: AuthV2Button(
            label: 'Continue   →',
            onPressed: _busy ? null : _continue,
            busy: _busy,
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, VoidCallback onTap, String icon) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AuthV2.label),
          const SizedBox(height: 7),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AuthV2.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AuthV2.body.copyWith(color: AuthV2.navy),
                    ),
                  ),
                  SvgPicture.asset('${AuthV2.assets}$icon'),
                ],
              ),
            ),
          ),
        ],
      );

  InputDecoration _decoration() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: AuthV2.border),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: AuthV2.teal),
      borderRadius: BorderRadius.circular(12),
    ),
  );

  String _month(int month) => const [
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
