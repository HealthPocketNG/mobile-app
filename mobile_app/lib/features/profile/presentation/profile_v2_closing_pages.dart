import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_common.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';
import 'package:url_launcher/url_launcher.dart';

Uri profileIssueEmailUri({
  required String category,
  required String details,
}) => _mailto(
  subject: 'HealthPocket issue · $category',
  body:
      'Category: $category\n\nWhat happened:\n$details\n\n'
      'Please add a screenshot in your email app if helpful. '
      'Do not include passwords, PINs, banking details, or medical records.',
);

Uri profileDeletionRequestUri() => _mailto(
  subject: 'HealthPocket account deletion request',
  body:
      'I would like to request deletion of my HealthPocket account.\n\n'
      'Please tell me the verification steps and what data must be retained.\n\n'
      'Do not include your password or PIN in this email.',
);

Uri _mailto({required String subject, required String body}) => Uri(
  scheme: 'mailto',
  path: supportEmail,
  query: {'subject': subject, 'body': body}.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('&'),
);

class ProfileLogoutSheet extends StatefulWidget {
  const ProfileLogoutSheet({required this.onLogOut, super.key});
  final Future<void> Function() onLogOut;
  @override
  State<ProfileLogoutSheet> createState() => _ProfileLogoutSheetState();
}

class _ProfileLogoutSheetState extends State<ProfileLogoutSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogOut();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not log out. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DBE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ProfileV2.mint,
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                '${ProfileV2.assets}2592e.svg',
                width: 30,
                height: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Log out of\nHealthPocket?',
              textAlign: TextAlign.center,
              style: profileText(20, FontWeight.w700, ProfileV2.navy),
            ),
            const SizedBox(height: 10),
            Text(
              "You'll need your PIN or\npassword to sign back in.",
              textAlign: TextAlign.center,
              style: profileText(
                13.5,
                FontWeight.w400,
                ProfileV2.muted,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            _ProfilePillButton(
              label: _busy ? 'Logging out…' : 'Log Out',
              onTap: _busy ? null : _confirm,
            ),
            const SizedBox(height: 10),
            _ProfilePillButton(
              label: 'Cancel',
              onTap: _busy ? null : () => Navigator.pop(context),
              secondary: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: profileText(12, FontWeight.w500, ProfileV2.pink),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ProfileDeleteAccountScreen extends StatefulWidget {
  const ProfileDeleteAccountScreen({super.key, this.openEmail});
  final Future<bool> Function(Uri)? openEmail;
  @override
  State<ProfileDeleteAccountScreen> createState() =>
      _ProfileDeleteAccountScreenState();
}

class _ProfileDeleteAccountScreenState
    extends State<ProfileDeleteAccountScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _requestDeletion() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final opened =
          await (widget.openEmail?.call(profileDeletionRequestUri()) ??
              launchUrl(profileDeletionRequestUri()));
      if (mounted) {
        setState(
          () => _message = opened
              ? 'Complete and send the request in your email app. Your account has not been deleted.'
              : 'Could not open an email app. Contact support to request account deletion.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not open an email app. Contact support to request account deletion.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Delete account',
    subtitle: "This permanently deletes your HealthPocket account.\nIt can't be undone.",
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfilePillButton(
            label: 'Keep My Account',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
          _ProfilePillButton(
            label: _busy ? 'Opening…' : 'Continue to Delete',
            onTap: _busy ? null : _requestDeletion,
            danger: true,
          ),
        ],
      ),
    ),
    children: [
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: ProfileV2.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: const [
            _DeleteConsequence(
              asset: '65c73.svg',
              iconHeight: 44,
              label: 'Your savings plan and Family Pocket memberships will be removed',
            ),
            _DeleteConsequence(
              asset: '03a2c.svg',
              iconHeight: 26,
              label: "You'll lose access to your activity and receipts",
            ),
            _DeleteConsequence(
              asset: 'a363b.svg',
              iconHeight: 20,
              label: "You'll be signed out on all devices",
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ProfileV2.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              '${ProfileV2.assets}79d45.svg',
              width: 13,
              height: 47,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Before deletion, check any balance or pending activity. Some records may be kept as required by law.',
                style: profileText(
                  11.5,
                  FontWeight.w400,
                  ProfileV2.muted,
                ).copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(_message!)),
      ],
      const SizedBox(height: 18),
      Text(
        'Account deletion is handled by support while the self-service deletion flow is being built.',
        style: profileText(12, FontWeight.w400, ProfileV2.muted),
      ),
    ],
  );
}

class _DeleteConsequence extends StatelessWidget {
  const _DeleteConsequence({
    required this.asset,
    required this.iconHeight,
    required this.label,
  });
  final String asset, label;
  final double iconHeight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        SvgPicture.asset(
          '${ProfileV2.assets}$asset',
          width: asset == 'a363b.svg' ? 11.47 : 12,
          height: iconHeight,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: profileText(13.5, FontWeight.w400, ProfileV2.navy),
          ),
        ),
      ],
    ),
  );
}

class ProfileReportIssueScreen extends StatefulWidget {
  const ProfileReportIssueScreen({super.key, this.openEmail});
  final Future<bool> Function(Uri)? openEmail;
  @override
  State<ProfileReportIssueScreen> createState() =>
      _ProfileReportIssueScreenState();
}

class _ProfileReportIssueScreenState extends State<ProfileReportIssueScreen> {
  static const _categories = [
    'Payments',
    'Savings',
    'Family Pocket',
    'Account',
    'Other',
  ];
  final _details = TextEditingController();
  String _category = 'Payments';
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_details.text.trim().isEmpty) {
      setState(() => _message = 'Describe the issue before continuing.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final uri = profileIssueEmailUri(
        category: _category,
        details: _details.text.trim(),
      );
      final opened = await (widget.openEmail?.call(uri) ?? launchUrl(uri));
      if (mounted) {
        setState(
          () => _message = opened
              ? 'Finish and send the report in your email app. Nothing has been submitted by HealthPocket.'
              : 'Could not open an email app. Contact support to report the issue.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not open an email app. Contact support to report the issue.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Report an Issue',
    subtitle: 'Tell us what went wrong.',
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: _ProfilePillButton(
        label: _busy ? 'Opening…' : 'Submit Report',
        onTap: _busy ? null : _submit,
      ),
    ),
    children: [
      const SizedBox(height: 18),
      Text(
        "What's the issue about?",
        style: profileText(12.5, FontWeight.w600, ProfileV2.navy),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _category,
        icon: SvgPicture.asset(
          '${ProfileV2.assets}6bd4f.svg',
          width: 18,
          height: 18,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [
          for (final category in _categories)
            DropdownMenuItem(value: category, child: Text(category)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _category = value);
        },
      ),
      const SizedBox(height: 16),
      Text(
        'Describe the issue',
        style: profileText(12.5, FontWeight.w600, ProfileV2.navy),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _details,
        maxLines: 5,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Tell us what happened...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text(_message!)),
      ],
      const SizedBox(height: 4),
      Text(
        'Add a screenshot (optional)',
        style: profileText(12.5, FontWeight.w600, ProfileV2.navy),
      ),
      const SizedBox(height: 6),
      InkWell(
        onTap: () => profileMessage(
          context,
          'Add your screenshot in the email app after opening the report draft.',
        ),
        borderRadius: BorderRadius.circular(12),
        child: ProfileV2DashedOutline(
          color: const Color(0xFFB8C0C8),
          child: SizedBox(
            height: 88,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  '${ProfileV2.assets}df7d2.svg',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  'Add in email app',
                  style: profileText(12.5, FontWeight.w400, ProfileV2.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Leave out passwords, PINs, banking details, and medical records.',
        style: profileText(11.5, FontWeight.w400, ProfileV2.muted),
      ),
    ],
  );
}

class ProfileActiveSessionsScreen extends StatelessWidget {
  const ProfileActiveSessionsScreen({super.key});

  String get _deviceLabel {
    if (kIsWeb) return 'This browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android phone',
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.windows => 'Windows device',
      TargetPlatform.macOS => 'Mac device',
      TargetPlatform.linux => 'Linux device',
      TargetPlatform.fuchsia => 'This device',
    };
  }

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Active Sessions',
    subtitle: 'Devices that are signed in to your account.',
    bottomNavigationBar: const SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: _ProfilePillButton(
        label: 'Log Out of All Other Devices',
        onTap: null,
        danger: true,
      ),
    ),
    children: [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: ProfileV2.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ProfileV2Icon(
              asset: kIsWeb || defaultTargetPlatform == TargetPlatform.windows
                  ? '8ac44.svg'
                  : '67c57.svg',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This device',
                    style: profileText(14, FontWeight.w600, ProfileV2.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _deviceLabel,
                    style: profileText(12, FontWeight.w400, ProfileV2.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F6EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Active now',
                style: profileText(
                  11.5,
                  FontWeight.w500,
                  const Color(0xFF1E8E4E),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Other devices cannot be listed or signed out until account session management is available.',
        style: profileText(12, FontWeight.w400, ProfileV2.muted),
      ),
    ],
  );
}

class _ProfilePillButton extends StatelessWidget {
  const _ProfilePillButton({
    required this.label,
    required this.onTap,
    this.secondary = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool secondary, danger;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: secondary ? 46 : 52,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: danger
            ? const Color(0xFFFDE8EE)
            : secondary
            ? ProfileV2.mint
            : ProfileV2.teal,
        disabledBackgroundColor: danger
            ? const Color(0xFFFDE8EE)
            : ProfileV2.mint,
        foregroundColor: danger
            ? ProfileV2.pink
            : secondary
            ? ProfileV2.teal
            : Colors.white,
        disabledForegroundColor: danger
            ? ProfileV2.pink.withValues(alpha: .55)
            : ProfileV2.muted,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: profileText(
          15,
          FontWeight.w600,
          onTap == null && !danger
              ? ProfileV2.muted
              : danger
              ? ProfileV2.pink
              : secondary
              ? ProfileV2.teal
              : Colors.white,
        ),
      ),
    ),
  );
}
