import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.store, super.key});

  final ProfileStore store;

  Future<void> _editAccount(BuildContext context) async {
    final draft = await showModalBottomSheet<_AccountDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditAccountSheet(profile: store.profile),
    );
    if (draft == null) return;
    store.updateAccount(
      fullName: draft.fullName,
      email: draft.email,
      phoneNumber: draft.phoneNumber,
      stateOfResidence: draft.stateOfResidence,
    );
    if (context.mounted) _showMessage(context, 'Account information updated');
  }

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ChangePasswordSheet(),
    );
    if (changed == true && context.mounted) {
      _showMessage(context, 'Demo password updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final profile = store.profile;
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Account information'),
              const SizedBox(height: AppSpacing.sm),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Account details',
                    subtitle: '${profile.email} • ${profile.phoneNumber}',
                    onTap: () => _editAccount(context),
                  ),
                  _SettingsTile(
                    icon: Icons.home_outlined,
                    title: 'Personal information',
                    subtitle: _personalInformationLabel(profile),
                  ),
                  _SettingsTile(
                    icon: Icons.contact_emergency_outlined,
                    title: 'Emergency contact',
                    subtitle: profile.nextOfKinName.isEmpty
                        ? 'Not provided'
                        : '${profile.nextOfKinName} • ${profile.nextOfKinPhone}',
                  ),
                  _SettingsTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Verification status',
                    subtitle: _verificationLabel(profile),
                    trailing: _StatusBadge(
                      label: profile.demoKycComplete ? 'Demo KYC' : 'Pending',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Security settings'),
              const SizedBox(height: AppSpacing.sm),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    subtitle: 'Keep your account protected',
                    onTap: () => _changePassword(context),
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('biometric-unlock-switch'),
                    secondary: const _SettingsIcon(
                      icon: Icons.fingerprint_rounded,
                    ),
                    title: const Text('Biometric unlock'),
                    subtitle: const Text('Use your device security to sign in'),
                    value: store.biometricUnlock,
                    onChanged: store.setBiometricUnlock,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Notification preferences'),
              const SizedBox(height: AppSpacing.sm),
              _SettingsCard(
                children: [
                  _PreferenceSwitch(
                    switchKey: const ValueKey('savings-reminders-switch'),
                    icon: Icons.savings_outlined,
                    title: 'Savings reminders',
                    subtitle: 'Plan schedule and contribution reminders',
                    value: store.notifications.savingsReminders,
                    onChanged: store.setSavingsReminderNotifications,
                  ),
                  _PreferenceSwitch(
                    switchKey: const ValueKey('family-activity-switch'),
                    icon: Icons.groups_2_outlined,
                    title: 'Family activity',
                    subtitle: 'Invites and shared-pocket updates',
                    value: store.notifications.familyActivity,
                    onChanged: store.setFamilyActivityNotifications,
                  ),
                  _PreferenceSwitch(
                    switchKey: const ValueKey('health-reminders-switch'),
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health reminders',
                    subtitle: 'Helpful prompts for your healthcare plans',
                    value: store.notifications.healthReminders,
                    onChanged: store.setHealthReminders,
                  ),
                  _PreferenceSwitch(
                    switchKey: const ValueKey('product-updates-switch'),
                    icon: Icons.campaign_outlined,
                    title: 'Product updates',
                    subtitle: 'New HealthPocket feature announcements',
                    value: store.notifications.productUpdates,
                    onChanged: store.setProductUpdates,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Help & support'),
              const SizedBox(height: AppSpacing.sm),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Frequently asked questions',
                    subtitle: 'Learn how the Month 1 demo works',
                    onTap: () => _showHelp(context),
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Contact support',
                    subtitle: 'Send a demo support request',
                    onTap: () =>
                        _showMessage(context, 'Demo support request created'),
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Privacy and terms',
                    subtitle: 'Review how HealthPocket protects your data',
                    onTap: () => _showMessage(
                      context,
                      'Legal documents will be connected before release',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoute.welcome.path,
                  (route) => false,
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out of demo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.outline),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'HealthPocket demo • Version 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomNavigation(currentIndex: 3),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              _initials(profile.fullName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile.stateOfResidence} • Member since ${profile.memberSince.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, indent: 64),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _SettingsIcon(icon: icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded, size: 20)),
      onTap: onTap,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: switchKey,
      secondary: _SettingsIcon(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _EditAccountSheet extends StatefulWidget {
  const _EditAccountSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _stateController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _emailController = TextEditingController(text: widget.profile.email);
    _phoneController = TextEditingController(text: widget.profile.phoneNumber);
    _stateController = TextEditingController(
      text: widget.profile.stateOfResidence,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _stateController.dispose();
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
            _sheetTitle(context, 'Edit account information'),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _stateController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'State of residence',
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Save changes',
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _AccountDraft(
                    fullName: _nameController.text.trim(),
                    email: _emailController.text.trim(),
                    phoneNumber: _phoneController.text.trim(),
                    stateOfResidence: _stateController.text.trim(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
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
            _sheetTitle(context, 'Change password'),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _confirmationController,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Update demo password',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
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

class _AccountDraft {
  const _AccountDraft({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.stateOfResidence,
  });

  final String fullName;
  final String email;
  final String phoneNumber;
  final String stateOfResidence;
}

void _showHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => const _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently asked questions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: AppSpacing.lg),
          _HelpAnswer(
            question: 'Is this real money?',
            answer: 'No. Month 1 contributions and balances are demonstration data only.',
          ),
          _HelpAnswer(
            question: 'Can family members contribute?',
            answer: 'The demo records shared contributions without processing a payment.',
          ),
          _HelpAnswer(
            question: 'Are investments available?',
            answer: 'No. Investment and payment partners are outside the Month 1 scope.',
          ),
        ],
      ),
    ),
  );
}

class _HelpAnswer extends StatelessWidget {
  const _HelpAnswer({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(answer, style: const TextStyle(color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

Widget _sheetTitle(BuildContext context, String title) => Text(
  title,
  style: Theme.of(context).textTheme.titleLarge
      ?.copyWith(fontWeight: FontWeight.w800),
);

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase())
    .join();

String _verificationLabel(UserProfile profile) {
  final contactStatus = profile.emailVerified && profile.phoneVerified
      ? 'Email and phone verified'
      : profile.phoneVerified
      ? 'Phone verified • Email pending'
      : profile.emailVerified
      ? 'Email verified • Phone pending'
      : 'Email and phone pending';
  return profile.demoKycComplete
      ? '$contactStatus • Demo KYC complete'
      : '$contactStatus • Demo KYC pending';
}

String _personalInformationLabel(UserProfile profile) {
  final date = profile.dateOfBirth;
  final dateLabel = date == null
      ? 'Date of birth not provided'
      : '${date.day}/${date.month}/${date.year}';
  final residence = profile.residentialAddress.isEmpty
      ? profile.stateOfResidence
      : '${profile.residentialAddress}, ${profile.stateOfResidence}';
  return residence.isEmpty ? dateLabel : '$dateLabel • $residence';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
