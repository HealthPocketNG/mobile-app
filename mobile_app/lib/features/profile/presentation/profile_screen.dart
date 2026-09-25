import 'package:flutter/material.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';
import 'package:healthpocket/features/profile/presentation/edit_personal_details_screen.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/initials_avatar.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.store,
    super.key,
    this.authRepository,
    this.onSaveNotificationPreferences,
    this.onSaveAccount,
    this.onSavePersonalDetails,
  });

  final ProfileStore store;
  final AuthRepository? authRepository;
  final Future<void> Function(UserProfile profile)? onSaveAccount;
  final Future<void> Function(UserProfile profile, bool emergencyContact)?
  onSavePersonalDetails;
  final Future<void> Function(NotificationPreferences notifications)?
  onSaveNotificationPreferences;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _savingNotifications = false;

  ProfileStore get store => widget.store;
  AuthRepository? get authRepository => widget.authRepository;

  Future<void> _editDetails(bool emergencyContact) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPersonalDetailsScreen(
          profile: store.profile,
          emergencyContact: emergencyContact,
          onSave: (draft) async {
            final save = widget.onSavePersonalDetails;
            if (save != null) {
              await save(draft, emergencyContact);
            } else {
              store.hydrate(profile: draft, notifications: store.notifications);
            }
          },
        ),
      ),
    );
    if (mounted && saved == true) {
      _showMessage(context, 'Profile details saved');
    }
  }

  Future<void> _editAccount(BuildContext context) async {
    final draft = await showModalBottomSheet<_AccountDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditAccountSheet(
        profile: store.profile,
        onSave: (draft) async {
          final save = widget.onSaveAccount;
          if (save != null) {
            await save(
              store.profile.copyWith(
                fullName: draft.fullName,
                phoneNumber: draft.phoneNumber,
                stateOfResidence: draft.stateOfResidence,
              ),
            );
          } else {
            store.updateAccount(
              fullName: draft.fullName,
              email: store.profile.email,
              phoneNumber: draft.phoneNumber,
              stateOfResidence: draft.stateOfResidence,
            );
          }
        },
      ),
    );
    if (draft == null) return;
    if (context.mounted) _showMessage(context, 'Account information updated');
  }

  Future<void> _resetPassword(BuildContext context) async {
    final email = authRepository?.currentUser?.email ?? store.profile.email;
    if (email.isEmpty || authRepository == null) return;
    try {
      await authRepository!.sendPasswordResetEmail(email);
      if (context.mounted) {
        _showMessage(context, 'Password-reset instructions sent to $email');
      }
    } on AuthFailure catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await authRepository?.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoute.welcome.path,
      (route) => false,
    );
  }

  Future<void> _saveNotifications(
    BuildContext context,
    NotificationPreferences notifications,
  ) async {
    if (_savingNotifications) return;
    setState(() => _savingNotifications = true);
    try {
      final save = widget.onSaveNotificationPreferences;
      if (save == null) {
        store.replaceNotifications(notifications);
      } else {
        await save(notifications);
      }
      if (context.mounted) {
        _showMessage(context, 'Notification preference saved');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'We could not save that preference. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, child) {
        final profile = store.profile;
        return Scaffold(
          appBar: AppBar(title: const Text('More')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              Text(
                'Manage your account and settings.',
                style: const TextStyle(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileHeader(profile: profile),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle('Quick access'),
              const SizedBox(height: AppSpacing.sm),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.savings_outlined,
                    title: 'Savings',
                    subtitle: 'Manage your health fund',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoute.savings.path),
                  ),
                  _SettingsTile(
                    icon: Icons.groups_2_outlined,
                    title: 'Family Pocket',
                    subtitle: 'Save together for care',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoute.familyPocket.path,
                    ),
                  ),
                ],
              ),
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
                    onTap: () => _editDetails(false),
                    subtitle: _personalInformationLabel(profile),
                  ),
                  _SettingsTile(
                    icon: Icons.contact_emergency_outlined,
                    title: 'Emergency contact',
                    onTap: () => _editDetails(true),
                    subtitle: profile.nextOfKinName.isEmpty
                        ? 'Not provided'
                        : '${profile.nextOfKinName} • ${profile.nextOfKinPhone}',
                  ),
                  _SettingsTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Email verification',
                    subtitle:
                        authRepository?.currentUser?.email ?? profile.email,
                    trailing: _StatusBadge(
                      label:
                          authRepository?.currentUser?.emailVerified == true ||
                              profile.emailVerified
                          ? 'Verified'
                          : 'Pending',
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
                    title: 'Reset password',
                    subtitle: 'Receive a secure reset link by email',
                    onTap: authRepository == null
                        ? null
                        : () => _resetPassword(context),
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
                    onChanged: _savingNotifications
                        ? null
                        : (value) => _saveNotifications(
                            context,
                            store.notifications.copyWith(
                              savingsReminders: value,
                            ),
                          ),
                  ),
                  _PreferenceSwitch(
                    switchKey: const ValueKey('family-activity-switch'),
                    icon: Icons.groups_2_outlined,
                    title: 'Family activity',
                    subtitle: 'Invites and shared-pocket updates',
                    value: store.notifications.familyActivity,
                    onChanged: _savingNotifications
                        ? null
                        : (value) => _saveNotifications(
                            context,
                            store.notifications.copyWith(familyActivity: value),
                          ),
                  ),
                  _PreferenceSwitch(
                    switchKey: const ValueKey('health-reminders-switch'),
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health reminders',
                    subtitle: 'Helpful prompts for your healthcare plans',
                    value: store.notifications.healthReminders,
                    onChanged: _savingNotifications
                        ? null
                        : (value) => _saveNotifications(
                            context,
                            store.notifications.copyWith(
                              healthReminders: value,
                            ),
                          ),
                  ),
                  _PreferenceSwitch(
                    switchKey: const ValueKey('product-updates-switch'),
                    icon: Icons.campaign_outlined,
                    title: 'Product updates',
                    subtitle: 'New HealthPocket feature announcements',
                    value: store.notifications.productUpdates,
                    onChanged: _savingNotifications
                        ? null
                        : (value) => _saveNotifications(
                            context,
                            store.notifications.copyWith(productUpdates: value),
                          ),
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
                    subtitle: 'Understand the no-money beta',
                    onTap: () => _showHelp(context),
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Contact support',
                    subtitle: 'Email us or share beta feedback',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const SupportScreen(),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'About HealthPocket',
                    subtitle: 'Beta app information, privacy and terms',
                    onTap: () => _showMessage(
                      context,
                      'Legal documents will be connected before release',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.outline),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'HealthPocket MVP • Version 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
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
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
  final ValueChanged<bool>? onChanged;

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
  const _EditAccountSheet({required this.profile, required this.onSave});

  final UserProfile profile;

  final Future<void> Function(_AccountDraft draft) onSave;

  @override
  State<_EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends State<_EditAccountSheet> {
  bool _saving = false;
  String? _error;
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
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email address',
                helperText: 'Managed by your sign-in account',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number (optional)',
              ),
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
            const Text('Your sign-in email cannot be changed here.'),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            AppPrimaryButton(
              label: _saving ? 'Saving…' : 'Save changes',
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      final draft = _AccountDraft(
                        fullName: _nameController.text.trim(),
                        email: _emailController.text.trim(),
                        phoneNumber: _phoneController.text.trim(),
                        stateOfResidence: _stateController.text.trim(),
                      );
                      setState(() {
                        _saving = true;
                        _error = null;
                      });
                      try {
                        await widget.onSave(draft);
                        if (context.mounted) Navigator.pop(context, draft);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _error = 'We could not save your changes. Check your connection and try again.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
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
            answer: 'No. Beta contributions and balances are simulated records. No money is deposited, held, or transferred.',
          ),
          _HelpAnswer(
            question: 'Can family members contribute?',
            answer: 'The demo records shared contributions without processing a payment.',
          ),
          _HelpAnswer(
            question: 'Are investments available?',
            answer: 'No. Investments and real payments are not available in this beta.',
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

String _initials(String name) => InitialsAvatar.initialsFor(name);

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
