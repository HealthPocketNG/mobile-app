import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';
import 'package:healthpocket/features/profile/presentation/edit_personal_details_screen.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_common.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_pages.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_more_pages.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_final_pages.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_closing_pages.dart';
import 'package:healthpocket/features/auth/data/biometric_unlock_service.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/app_notification_bell.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/domain/profile_photo.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';

typedef ProfilePhotoUploadCallback = Future<void> Function(
  Uint8List bytes,
  String contentType,
);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.store,
    super.key,
    this.authRepository,
    this.onSignOut,
    this.onSaveNotificationPreferences,
    this.onSaveAccount,
    this.onSavePersonalDetails,
    this.profilePhotoRepository,
    this.providerPhotoUrl,
    this.onUploadProfilePhoto,
    this.onRemoveProfilePhoto,
    this.savingsStore,
    this.biometricService,
    this.designPreview = false,
    this.onSetPin,
  });

  final ProfileStore store;
  final AuthRepository? authRepository;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(UserProfile profile)? onSaveAccount;
  final Future<void> Function(UserProfile profile, bool emergencyContact)?
  onSavePersonalDetails;
  final Future<void> Function(NotificationPreferences notifications)?
  onSaveNotificationPreferences;
  final ProfilePhotoRepository? profilePhotoRepository;
  final String? providerPhotoUrl;
  final ProfilePhotoUploadCallback? onUploadProfilePhoto;
  final Future<void> Function()? onRemoveProfilePhoto;
  final SavingsStore? savingsStore;
  final BiometricUnlockService? biometricService;
  final bool designPreview;
  final Future<void> Function(String pin)? onSetPin;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _savingNotifications = false;
  bool _savingPhoto = false;

  ProfileStore get store => widget.store;
  AuthRepository? get authRepository => widget.authRepository;

  Future<void> _editPhoto() async {
    if (_savingPhoto) return;
    final action = await showModalBottomSheet<ProfilePhotoAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ProfileChangePhotoSheet(),
    );
    if (!mounted || action == null) return;
    if (action == ProfilePhotoAction.remove &&
        store.profile.profileImagePath == null) {
      profileMessage(context, 'No uploaded photo to remove.');
      return;
    }
    if (action == ProfilePhotoAction.remove &&
            widget.onRemoveProfilePhoto == null ||
        action != ProfilePhotoAction.remove &&
            widget.onUploadProfilePhoto == null) {
      profileMessage(
        context,
        'Photo changes will be available after account storage is ready.',
      );
      return;
    }
    setState(() => _savingPhoto = true);
    try {
      if (action == ProfilePhotoAction.remove) {
        await widget.onRemoveProfilePhoto?.call();
        if (mounted) _showMessage(context, 'Profile photo removed');
        return;
      }
      final file = await ImagePicker().pickImage(
        source: action == ProfilePhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final contentType = ProfilePhotoPolicy.detectContentType(bytes);
      if (contentType == null) {
        throw const FormatException('Unsupported profile photo type.');
      }
      if (bytes.isEmpty || bytes.length > ProfilePhotoPolicy.maximumBytes) {
        throw const FormatException('Profile photo is too large.');
      }
      await widget.onUploadProfilePhoto!(bytes, contentType);
      if (mounted) _showMessage(context, 'Profile photo updated');
    } catch (_) {
      if (mounted) {
        _showMessage(
          context,
          'Use a JPG, PNG, or WebP image no larger than 5 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

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

  Future<void> _signOut(BuildContext context) async {
    final signOut = widget.onSignOut;
    if (signOut != null) {
      await signOut();
    } else {
      final repository = authRepository;
      if (repository == null) throw StateError('No active sign-out service.');
      await repository.signOut();
    }
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoute.welcome.path,
      (route) => false,
    );
  }

  void _showLogout() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    barrierColor: ProfileV2.navy.withValues(alpha: .5),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ProfileLogoutSheet(onLogOut: () => _signOut(context)),
  );

  void _openDeleteAccount() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const ProfileDeleteAccountScreen()),
  );

  void _openActiveSessions() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const ProfileActiveSessionsScreen(),
    ),
  );

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

  void _openPersonalInformation() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnimatedBuilder(
          animation: store,
          builder: (context, _) => ProfilePersonalInfoScreen(
            profile: store.profile,
            userId: authRepository?.currentUserId,
            photoRepository: widget.profilePhotoRepository,
            providerPhotoUrl: widget.providerPhotoUrl,
            onPhoto: _editPhoto,
            onEdit: _showEditChoices,
          ),
        ),
      ),
    );
  }

  void _showEditChoices() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Name and phone number'),
              subtitle: const Text('Edit your account basics'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editAccount(context);
              },
            ),
            ListTile(
              title: const Text('Date of birth and location'),
              subtitle: const Text('Edit your personal details'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editDetails(false);
              },
            ),
            ListTile(
              title: const Text('Emergency contact'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editDetails(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSecurity() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProfileSecurityScreen(
        onPersonalInformation: _openPersonalInformation,
        onLoginPin: _openLoginPin,
        onDeleteAccount: _openDeleteAccount,
        onActiveSessions: _openActiveSessions,
      ),
    ),
  );

  void _openLoginPin() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProfileLoginPinScreen(
        profileStore: store,
        biometricService: widget.biometricService,
        userId: authRepository?.currentUserId,
        authRepository: authRepository,
        onSetPin: widget.onSetPin,
      ),
    ),
  );

  void _openPaymentMethods() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProfilePaymentMethodsScreen(
        savingsStore: widget.savingsStore,
        designPreview: widget.designPreview,
      ),
    ),
  );

  void _openAbout() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const ProfileAboutScreen()),
  );

  void _openNotificationSettings() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProfileNotificationSettingsScreen(
        store: store,
        onSave: _saveNotifications,
      ),
    ),
  );

  void _openSupport() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
  );

  Widget _buildV2(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final profile = store.profile;
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'More',
                            style: profileText(
                              26,
                              FontWeight.w700,
                              ProfileV2.teal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your account and\nsettings.',
                            style: profileText(
                              12,
                              FontWeight.w400,
                              ProfileV2.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppNotificationBell(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoute.notifications.path,
                      ),
                      iconSize: 23,
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _openPersonalInformation,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB5EDE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SvgPicture.asset(
                          '${ProfileV2.assets}91e10.svg',
                          width: 22,
                          height: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Material(
                  color: const Color(0xFFEEF9F7),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _openPersonalInformation,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ProfileV2Photo(
                            profile: profile,
                            userId: authRepository?.currentUserId,
                            repository: widget.profilePhotoRepository,
                            providerPhotoUrl: widget.providerPhotoUrl,
                            radius: 32,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: profileText(
                                    15,
                                    FontWeight.w700,
                                    ProfileV2.navy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: profileText(
                                    12,
                                    FontWeight.w400,
                                    ProfileV2.muted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'View profile ›',
                                  style: profileText(
                                    12,
                                    FontWeight.w500,
                                    ProfileV2.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SvgPicture.asset(
                            '${ProfileV2.assets}f60f9.svg',
                            width: 16,
                            height: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _overviewRow('02a29.svg', 'Account & Security', _openSecurity),
                _overviewRow(
                  '68563.svg',
                  'Savings',
                  () => Navigator.pushNamed(context, AppRoute.savings.path),
                ),
                _overviewRow(
                  '10141.svg',
                  'Family Pocket',
                  () =>
                      Navigator.pushNamed(context, AppRoute.familyPocket.path),
                ),
                _overviewRow(
                  'e38c3.svg',
                  'Payment Methods',
                  _openPaymentMethods,
                ),
                _overviewRow(
                  'cc73a.svg',
                  'Notifications',
                  _openNotificationSettings,
                ),
                _overviewRow('a4948.svg', 'Help & Support', _openSupport),
                _overviewRow(
                  '9b106.svg',
                  'About HealthPocket',
                  _openAbout,
                  last: true,
                ),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFFFDE8EE),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileReferScreen(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SvgPicture.asset(
                              '${ProfileV2.assets}34677.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Refer a Friend',
                                  style: profileText(
                                    14,
                                    FontWeight.w600,
                                    ProfileV2.pink,
                                  ),
                                ),
                                Text(
                                  'Help others stay healthy.\nYou both earn rewards!',
                                  style: profileText(
                                    11.5,
                                    FontWeight.w400,
                                    ProfileV2.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SvgPicture.asset(
                            '${ProfileV2.assets}f60f9.svg',
                            width: 16,
                            height: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 150),
                OutlinedButton.icon(
                  onPressed: _showLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const SafeArea(
            top: false,
            child: AppBottomNavigation(
              currentIndex: 4,
              assetRootOverride: ProfileV2.assets,
              iconFiles: [
                '40668.svg',
                '95340.svg',
                'f073d.svg',
                '5e36a.svg',
                '14584.svg',
              ],
              useAssetColorsOverride: true,
            ),
          ),
        ),
      );
    },
  );

  Widget _overviewRow(
    String asset,
    String label,
    VoidCallback onTap, {
    bool last = false,
  }) => Material(
    color: Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: ProfileV2.outline)),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              '${ProfileV2.assets}$asset',
              width: 22,
              height: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: profileText(14, FontWeight.w400, ProfileV2.navy),
              ),
            ),
            SvgPicture.asset(
              '${ProfileV2.assets}809a3.svg',
              width: 16,
              height: 16,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _buildV2(context);
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

Widget _sheetTitle(BuildContext context, String title) => Text(
  title,
  style: Theme.of(context).textTheme.titleLarge
      ?.copyWith(fontWeight: FontWeight.w800),
);

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
