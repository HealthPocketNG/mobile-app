import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_common.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_more_pages.dart';

class ProfileSecurityScreen extends StatelessWidget {
  const ProfileSecurityScreen({
    required this.onPersonalInformation,
    required this.onLoginPin,
    required this.onDeleteAccount,
    required this.onActiveSessions,
    super.key,
  });
  final VoidCallback onPersonalInformation;
  final VoidCallback onLoginPin;
  final VoidCallback onDeleteAccount;
  final VoidCallback onActiveSessions;

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Account & Security',
    subtitle: 'Keep your account safe and in your control.',
    children: [
      const SizedBox(height: 26),
      ProfileV2CardRow(
        asset: '90658.svg',
        title: 'Personal Information',
        subtitle: 'Name, email, phone, location',
        onTap: onPersonalInformation,
      ),
      ProfileV2CardRow(
        asset: '9fd04.svg',
        title: 'Login & PIN',
        subtitle: 'Change your PIN or password',
        onTap: onLoginPin,
      ),
      ProfileV2CardRow(
        asset: 'c2a2b.svg',
        title: 'Linked Accounts',
        subtitle: 'Google, banks and more',
        onTap: () =>
            profileMessage(context, 'Linked accounts are not available yet.'),
      ),
      ProfileV2CardRow(
        asset: '02a29.svg',
        title: 'Two-Factor Authentication',
        subtitle: 'Add an extra layer of security',
        onTap: () => profileMessage(
          context,
          'Two-factor settings are not available yet.',
        ),
      ),
      ProfileV2CardRow(
        asset: '67c57.svg',
        title: 'Active Sessions',
        subtitle: 'Manage your logged in devices',
        onTap: onActiveSessions,
      ),
      const SizedBox(height: 18),
      ProfileV2CardRow(
        asset: '07c9d.svg',
        title: 'Delete account',
        subtitle: 'Review account deletion',
        onTap: onDeleteAccount,
      ),
    ],
  );
}

class ProfilePersonalInfoScreen extends StatelessWidget {
  const ProfilePersonalInfoScreen({
    required this.profile,
    required this.onEdit,
    required this.onPhoto,
    super.key,
    this.userId,
    this.photoRepository,
    this.providerPhotoUrl,
  });
  final UserProfile profile;
  final VoidCallback onEdit, onPhoto;
  final String? userId, providerPhotoUrl;
  final ProfilePhotoRepository? photoRepository;

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Personal Information',
    subtitle: 'Keep your details up to date.',
    trailing: TextButton(
      onPressed: onEdit,
      child: Text(
        'Edit',
        style: profileText(14, FontWeight.w500, ProfileV2.teal),
      ),
    ),
    children: [
      const SizedBox(height: 22),
      Center(
        child: Stack(
          children: [
            ProfileV2Photo(
              profile: profile,
              userId: userId,
              repository: photoRepository,
              providerPhotoUrl: providerPhotoUrl,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: InkWell(
                key: const ValueKey('profile-change-photo'),
                onTap: onPhoto,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ProfileV2.navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: SvgPicture.asset(
                    '${ProfileV2.assets}f1df2.svg',
                    width: 16,
                    height: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _InfoField(label: 'Full name', value: profile.fullName),
      _InfoField(label: 'Email address', value: profile.email),
      _InfoField(
        label: 'Phone number',
        value: profile.phoneNumber.isEmpty
            ? 'Not provided'
            : profile.phoneNumber,
      ),
      _InfoField(
        label: 'Date of birth',
        value: profile.dateOfBirth == null
            ? 'Not provided'
            : _date(profile.dateOfBirth!),
        asset: 'db891.svg',
      ),
      _InfoField(
        label: 'Location',
        value: profile.stateOfResidence.isEmpty
            ? 'Not provided'
            : '${profile.stateOfResidence}, Nigeria',
        leadingAsset: 'f9e70.svg',
        asset: 'd0c1d.svg',
      ),
    ],
  );
}

String _date(DateTime value) {
  const months = [
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
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.label,
    required this.value,
    this.asset,
    this.leadingAsset,
  });
  final String label, value;
  final String? asset, leadingAsset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: profileText(12, FontWeight.w600, ProfileV2.navy)),
        const SizedBox(height: 5),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: ProfileV2.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (leadingAsset != null) ...[
                SvgPicture.asset(
                  '${ProfileV2.assets}$leadingAsset',
                  width: 18,
                  height: 18,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: profileText(14, FontWeight.w400, ProfileV2.muted),
                ),
              ),
              if (asset != null)
                SvgPicture.asset(
                  '${ProfileV2.assets}$asset',
                  width: 18,
                  height: 18,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileNotificationSettingsScreen extends StatelessWidget {
  const ProfileNotificationSettingsScreen({
    required this.store,
    required this.onSave,
    super.key,
    this.saving = false,
  });
  final ProfileStore store;
  final Future<void> Function(BuildContext, NotificationPreferences) onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final preferences = store.notifications;
      return ProfileV2Scaffold(
        title: 'Notifications',
        subtitle: 'Choose what you want to be notified about.',
        children: [
          const SizedBox(height: 22),
          const _PreferenceSection('Account'),
          _PreferenceRow(
            asset: '7dadf.svg',
            title: 'Login activity',
            subtitle: 'Get notified about new logins',
            value: false,
          ),
          _PreferenceRow(
            asset: 'e1fc9.svg',
            title: 'Security alerts',
            subtitle: 'Important security updates',
            value: false,
          ),
          const SizedBox(height: 18),
          const _PreferenceSection('Transactions'),
          _PreferenceRow(
            switchKey: const ValueKey('savings-reminders-switch'),
            asset: '353f5.svg',
            title: 'Savings contributions',
            subtitle: 'Savings reminders and deposits',
            value: preferences.savingsReminders,
            onChanged: saving
                ? null
                : (value) => onSave(
                    context,
                    preferences.copyWith(savingsReminders: value),
                  ),
          ),
          _PreferenceRow(
            asset: '77e6c.svg',
            title: 'Payments',
            subtitle: 'Get notified when you make payments',
            value: false,
          ),
          _PreferenceRow(
            switchKey: const ValueKey('family-activity-switch'),
            asset: 'fe231.svg',
            title: 'Family Pocket activity',
            subtitle: 'Updates from your family pockets',
            value: preferences.familyActivity,
            onChanged: saving
                ? null
                : (value) => onSave(
                    context,
                    preferences.copyWith(familyActivity: value),
                  ),
          ),
          const SizedBox(height: 18),
          const _PreferenceSection('Updates'),
          _PreferenceRow(
            switchKey: const ValueKey('product-updates-switch'),
            asset: 'a43df.svg',
            title: 'Product updates',
            subtitle: 'New features and improvements',
            value: preferences.productUpdates,
            onChanged: saving
                ? null
                : (value) => onSave(
                    context,
                    preferences.copyWith(productUpdates: value),
                  ),
          ),
          _PreferenceRow(
            switchKey: const ValueKey('health-reminders-switch'),
            asset: '1abbe.svg',
            title: 'Tips & health insights',
            subtitle: 'Helpful tips for a healthier you',
            value: preferences.healthReminders,
            background: const Color(0xFFFFEBC8),
            onChanged: saving
                ? null
                : (value) => onSave(
                    context,
                    preferences.copyWith(healthReminders: value),
                  ),
          ),
          _PreferenceRow(
            asset: '171f7.svg',
            title: 'Marketing & offers',
            subtitle: 'Special offers and partner deals',
            value: false,
            background: const Color(0xFFFDE8EE),
          ),
          const SizedBox(height: 12),
          Text(
            'Unavailable switches will be enabled when their notification services are ready.',
            style: profileText(11, FontWeight.w400, ProfileV2.muted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ProfileNotificationPermissionScreen(),
              ),
            ),
            child: const Text('Device notification permission'),
          ),
        ],
      );
    },
  );
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: profileText(14, FontWeight.w700, ProfileV2.navy)),
  );
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
    this.switchKey,
    this.background = ProfileV2.mint,
  });
  final String asset, title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;
  final Color background;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        ProfileV2Icon(asset: asset, background: background, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: profileText(13.5, FontWeight.w600, ProfileV2.navy),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: profileText(11.5, FontWeight.w400, ProfileV2.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: .78,
          child: Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: ProfileV2.teal,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD5DBE0),
          ),
        ),
      ],
    ),
  );
}
