import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/auth/data/biometric_unlock_service.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_common.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_final_pages.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

class ProfilePaymentMethodsScreen extends StatelessWidget {
  const ProfilePaymentMethodsScreen({
    super.key,
    this.savingsStore,
    this.designPreview = false,
  });
  final SavingsStore? savingsStore;
  final bool designPreview;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: savingsStore ?? const AlwaysStoppedAnimation<int>(0),
    builder: (context, _) => ProfileV2Scaffold(
      title: 'Payment Methods',
      subtitle: 'Manage how you pay and top up.',
      children: [
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: ProfileV2.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const ProfileV2Icon(asset: '6e2c5.svg'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HealthPocket Balance',
                      style: profileText(14, FontWeight.w600, ProfileV2.navy),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      designPreview
                          ? '${_naira(savingsStore?.developmentBalanceKobo ?? 0)} · Dev record'
                          : 'Not available for payments yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: profileText(12, FontWeight.w400, ProfileV2.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F6EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  designPreview ? 'Preview' : 'Pending',
                  style: profileText(
                    11,
                    FontWeight.w500,
                    const Color(0xFF1E8E4E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Bank accounts',
          style: profileText(13, FontWeight.w700, ProfileV2.muted),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF9F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SvgPicture.asset(
                '${ProfileV2.assets}435aa.svg',
                width: 22,
                height: 22,
              ),
              const SizedBox(height: 12),
              Text(
                'No bank accounts yet',
                style: profileText(14, FontWeight.w600, ProfileV2.navy),
              ),
              const SizedBox(height: 7),
              Text(
                'Add one to make topping up faster.',
                textAlign: TextAlign.center,
                style: profileText(13, FontWeight.w400, ProfileV2.muted),
              ),
              const SizedBox(height: 15),
              FilledButton(
                onPressed: () => profileMessage(
                  context,
                  'Bank account linking will be available when real payments are connected.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileV2.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Add Bank Account'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _naira(int kobo) {
  final digits = (kobo ~/ 100).toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₦$grouped';
}

class ProfileLoginPinScreen extends StatefulWidget {
  const ProfileLoginPinScreen({
    required this.profileStore,
    super.key,
    this.biometricService,
    this.userId,
    this.authRepository,
    this.onSetPin,
  });
  final ProfileStore profileStore;
  final BiometricUnlockService? biometricService;
  final String? userId;
  final AuthRepository? authRepository;
  final Future<void> Function(String pin)? onSetPin;
  @override
  State<ProfileLoginPinScreen> createState() => _ProfileLoginPinScreenState();
}

class _ProfileLoginPinScreenState extends State<ProfileLoginPinScreen> {
  bool _fingerprint = false;
  bool _available = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = widget.biometricService;
    final uid = widget.userId;
    if (service == null || uid == null) return;
    final available = await service.isAvailable();
    final enabled = await service.isEnabled(uid);
    if (mounted) {
      setState(() {
        _available = available;
        _fingerprint = enabled;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    final service = widget.biometricService;
    final uid = widget.userId;
    if (service == null || uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final enabled = await service.enable(uid);
        if (!mounted) return;
        if (!enabled) {
          profileMessage(
            context,
            'Fingerprint authentication was not enabled.',
          );
          return;
        }
      } else {
        await service.disable(uid);
      }
      widget.profileStore.setBiometricUnlock(value);
      if (mounted) setState(() => _fingerprint = value);
    } catch (_) {
      if (mounted) {
        profileMessage(
          context,
          'We could not update fingerprint login. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Login & PIN',
    subtitle: 'Control how you sign in to HealthPocket.',
    children: [
      const SizedBox(height: 22),
      ProfileV2CardRow(
        asset: '974af.svg',
        title: 'Change PIN',
        subtitle: 'Update your 6-digit PIN',
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ProfileResetPinScreen(
              authRepository: widget.authRepository,
              onSetPin: widget.onSetPin,
            ),
          ),
        ),
      ),
      ProfileV2CardRow(
        asset: '9fd04.svg',
        title: 'Change password',
        subtitle: 'Update your password',
        onTap: () => profileMessage(
          context,
          'Use password recovery from sign-in until in-session password change is available.',
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ProfileV2.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const ProfileV2Icon(asset: 'f90c3.svg'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fingerprint login',
                        style: profileText(14, FontWeight.w600, ProfileV2.navy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _available
                            ? 'Unlock with your fingerprint'
                            : 'Unavailable on this device',
                        style: profileText(
                          11.5,
                          FontWeight.w400,
                          ProfileV2.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: .78,
                  child: Switch(
                    key: const ValueKey('profile-fingerprint-switch'),
                    value: _fingerprint,
                    onChanged: _available && !_busy ? _toggle : null,
                    activeThumbColor: Colors.white,
                    activeTrackColor: ProfileV2.teal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ProfileV2CardRow(
        asset: '8acb3.svg',
        title: 'Auto-lock',
        subtitle: 'Lock the app after 1 minute away',
        onTap: () => profileMessage(
          context,
          'Auto-lock timing will be available with session controls.',
        ),
      ),
    ],
  );
}

enum ProfilePhotoAction { camera, gallery, remove }

class ProfileChangePhotoSheet extends StatelessWidget {
  const ProfileChangePhotoSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DBE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Change photo',
            style: profileText(20, FontWeight.w700, ProfileV2.navy),
          ),
          const SizedBox(height: 3),
          _PhotoAction(
            asset: '08fd2.svg',
            label: 'Take a photo',
            action: ProfilePhotoAction.camera,
          ),
          _PhotoAction(
            asset: 'c038d.svg',
            label: 'Choose from gallery',
            action: ProfilePhotoAction.gallery,
          ),
          _PhotoAction(
            asset: 'a3c6f.svg',
            label: 'Remove photo',
            action: ProfilePhotoAction.remove,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: ProfileV2.teal,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.asset,
    required this.label,
    required this.action,
  });
  final String asset, label;
  final ProfilePhotoAction action;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.pop(context, action),
    child: Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ProfileV2.outline)),
      ),
      child: Row(
        children: [
          SvgPicture.asset('${ProfileV2.assets}$asset', width: 22, height: 22),
          const SizedBox(width: 16),
          Text(label, style: profileText(14, FontWeight.w400, ProfileV2.navy)),
        ],
      ),
    ),
  );
}

class ProfileNotificationPermissionScreen extends StatelessWidget {
  const ProfileNotificationPermissionScreen({super.key});
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                '${ProfileV2.assets}fcb8b.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 22),
              Text(
                'Stay in the loop',
                style: profileText(20, FontWeight.w700, ProfileV2.navy),
              ),
              const SizedBox(height: 8),
              Text(
                'Get notified about payments, savings and\nFamily Pocket updates, so nothing slips by.',
                textAlign: TextAlign.center,
                style: profileText(
                  13.5,
                  FontWeight.w400,
                  ProfileV2.muted,
                ).copyWith(height: 1.5),
              ),
              const Spacer(flex: 5),
              FilledButton(
                onPressed: () => profileMessage(
                  context,
                  'Device notifications are not connected yet. No permission was changed.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileV2.teal,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('Turn On Notifications'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileV2.mint,
                  foregroundColor: ProfileV2.teal,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('Not Now'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileAboutScreen extends StatelessWidget {
  const ProfileAboutScreen({super.key});
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ProfileV2Back(onTap: () => Navigator.pop(context)),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const SizedBox(height: 22),
                    Center(
                      child: Image.asset(
                        'assets/HPLogo/HPLogo.png',
                        width: 220,
                        height: 162,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.0.0 (Beta)',
                      textAlign: TextAlign.center,
                      style: profileText(13, FontWeight.w400, ProfileV2.muted),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: ProfileV2.outline),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _AboutRow(
                            asset: '07c9d.svg',
                            label: 'Terms of Service',
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const ProfileTermsScreen(),
                              ),
                            ),
                          ),
                          _AboutRow(
                            asset: '02a29.svg',
                            label: 'Privacy Policy',
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const ProfileTermsScreen(
                                  initialPrivacy: true,
                                ),
                              ),
                            ),
                          ),
                          _AboutRow(
                            asset: '788f9.svg',
                            label: 'Rate HealthPocket',
                            last: true,
                            onTap: () => profileMessage(
                              context,
                              'App ratings will be available after store release.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'People care. Communities grow. Brighter days.',
                textAlign: TextAlign.center,
                style: profileText(13, FontWeight.w400, ProfileV2.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.asset,
    required this.label,
    required this.onTap,
    this.last = false,
  });
  final String asset, label;
  final VoidCallback onTap;
  final bool last;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: ProfileV2.outline)),
      ),
      child: Row(
        children: [
          SvgPicture.asset('${ProfileV2.assets}$asset', width: 22, height: 22),
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
  );
}
