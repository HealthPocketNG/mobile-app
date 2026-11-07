import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_common.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileReferScreen extends StatelessWidget {
  const ProfileReferScreen({super.key});

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ProfileV2Back(onTap: () => Navigator.pop(context)),
            ),
            const SizedBox(height: 16),
            Center(
              child: ProfileV2Icon(
                asset: 'c929b.svg',
                background: const Color(0xFFFDE8EE),
                size: 112,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Refer a friend',
              textAlign: TextAlign.center,
              style: profileText(22, FontWeight.w700, ProfileV2.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Help others stay healthy.\nYou both earn rewards!',
              textAlign: TextAlign.center,
              style: profileText(13.5, FontWeight.w400, ProfileV2.muted),
            ),
            const SizedBox(height: 16),
            ProfileV2DashedOutline(
              color: const Color(0xFF13A39B),
              radius: 14,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF9F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your referral code',
                      style: profileText(
                        11.5,
                        FontWeight.w400,
                        ProfileV2.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Not available yet',
                      style: profileText(18, FontWeight.w700, ProfileV2.teal),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final (index, step) in const [
              'Share your code with a friend',
              'They sign up and start saving',
              'You both earn rewards',
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: ProfileV2.mint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: profileText(13, FontWeight.w700, ProfileV2.teal),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: profileText(
                          13.5,
                          FontWeight.w400,
                          ProfileV2.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Row(
              children: const [
                Expanded(
                  child: _ReferralStat(value: '—', label: 'Friends joined'),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _ReferralStat(value: '—', label: 'Rewards earned'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Referral codes and rewards will appear when the referral programme is available.',
              textAlign: TextAlign.center,
              style: profileText(12, FontWeight.w400, ProfileV2.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Share Invite'),
        ),
      ),
    ),
  );
}

class _ReferralStat extends StatelessWidget {
  const _ReferralStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    height: 86,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF9F7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(value, style: profileText(18, FontWeight.w700, ProfileV2.teal)),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: profileText(11.5, FontWeight.w400, ProfileV2.muted),
        ),
      ],
    ),
  );
}

class ProfileResetPinScreen extends StatefulWidget {
  const ProfileResetPinScreen({super.key, this.authRepository, this.onSetPin});
  final AuthRepository? authRepository;
  final Future<void> Function(String pin)? onSetPin;

  @override
  State<ProfileResetPinScreen> createState() => _ProfileResetPinScreenState();
}

class _ProfileResetPinScreenState extends State<ProfileResetPinScreen> {
  final _password = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  bool _verified = false;
  String? _error;
  String? _verifiedUid;

  bool get _googleOnly =>
      widget.authRepository?.currentUser?.usesGoogle == true &&
      widget.authRepository?.currentUser?.usesPassword != true;

  @override
  void dispose() {
    _password.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final repo = widget.authRepository;
    final uid = repo?.currentUserId;
    if (repo == null || uid == null || widget.onSetPin == null) {
      setState(() => _error = 'PIN reset is unavailable in this session.');
      return;
    }
    if (!_googleOnly && _password.text.isEmpty) {
      setState(() => _error = 'Enter your account password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final okay = _googleOnly
          ? await repo.reauthenticateWithGoogle()
          : await repo.reauthenticateWithEmail(_password.text);
      if (!mounted) return;
      if (!okay || repo.currentUserId != uid) {
        setState(() => _error = 'Account confirmation did not complete.');
        return;
      }
      _password.clear();
      setState(() {
        _verified = true;
        _verifiedUid = uid;
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not confirm your account. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_newPin.text)) {
      setState(() => _error = 'Enter a 6-digit PIN.');
      return;
    }
    if (_newPin.text != _confirmPin.text) {
      setState(() => _error = 'The PINs do not match.');
      return;
    }
    if (_verifiedUid == null ||
        widget.authRepository?.currentUserId != _verifiedUid) {
      setState(
        () => _error = 'Your session changed. Confirm your account again.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSetPin!(_newPin.text);
      if (!mounted) return;
      profileMessage(context, 'Your PIN has been updated.');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not update your PIN. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ProfileV2Back(onTap: () => Navigator.pop(context)),
            ),
            const SizedBox(height: 40),
            Center(child: ProfileV2Icon(asset: '99e58.svg', size: 64)),
            const SizedBox(height: 14),
            Text(
              _verified ? 'Set a new PIN' : 'Reset your PIN',
              textAlign: TextAlign.center,
              style: profileText(22, FontWeight.w700, ProfileV2.navy),
            ),
            const SizedBox(height: 8),
            Text(
              _verified
                  ? 'Enter and confirm your new 6-digit PIN.'
                  : _googleOnly
                  ? 'Confirm your Google account to continue.'
                  : "Enter your password to confirm\nit's you.",
              textAlign: TextAlign.center,
              style: profileText(13.5, FontWeight.w400, ProfileV2.muted),
            ),
            const SizedBox(height: 28),
            if (!_verified && !_googleOnly) ...[
              Text(
                'Password',
                style: profileText(12.5, FontWeight.w600, ProfileV2.navy),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _password,
                obscureText: !_showPassword,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoute.forgotPassword.path,
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
            ],
            if (_verified) ...[
              TextField(
                controller: _newPin,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPin,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: 'Confirm new PIN'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: profileText(12, FontWeight.w500, ProfileV2.pink),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton.icon(
          onPressed: _busy ? null : (_verified ? _save : _verify),
          style: FilledButton.styleFrom(
            backgroundColor: ProfileV2.teal,
            minimumSize: const Size.fromHeight(52),
          ),
          label: Text(
            _busy ? 'Please wait…' : (_verified ? 'Save PIN' : 'Continue'),
          ),
          icon: _googleOnly && !_verified
              ? SvgPicture.asset(
                  'assets/auth/v2/google_g.svg',
                  width: 18,
                  height: 18,
                )
              : SvgPicture.asset(
                  '${ProfileV2.assets}4695b.svg',
                  width: 20,
                  height: 20,
                ),
        ),
      ),
    ),
  );
}

class ProfileContactSupportScreen extends StatefulWidget {
  const ProfileContactSupportScreen({super.key, this.openEmail});
  final Future<bool> Function(Uri)? openEmail;
  @override
  State<ProfileContactSupportScreen> createState() =>
      _ProfileContactSupportScreenState();
}

class _ProfileContactSupportScreenState
    extends State<ProfileContactSupportScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _email() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final opened =
          await (widget.openEmail?.call(supportEmailUri()) ??
              launchUrl(supportEmailUri()));
      if (mounted) {
        setState(
          () => _message = opened
              ? 'Finish and send your message in your email app. Nothing has been sent by HealthPocket.'
              : 'Could not open an email app. Copy the address below and email us from your preferred service.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not open an email app. Copy the address below and email us from your preferred service.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: 'Contact Support',
    subtitle: "We're here to help.",
    children: [
      const SizedBox(height: 18),
      ProfileV2CardRow(
        asset: '24cfc.svg',
        title: 'Chat with us',
        subtitle: 'Live chat is coming soon',
        onTap: () => profileMessage(context, 'Live chat is not available yet.'),
      ),
      ProfileV2CardRow(
        asset: '7f402.svg',
        title: 'Call us',
        subtitle: 'Phone support is coming soon',
        onTap: () =>
            profileMessage(context, 'Phone support is not available yet.'),
      ),
      ProfileV2CardRow(
        asset: 'e8297.svg',
        title: 'Email us',
        subtitle: supportEmail,
        onTap: _busy ? () {} : _email,
      ),
      ProfileV2CardRow(
        asset: 'cfc46.svg',
        title: 'WhatsApp',
        subtitle: 'Messaging is coming soon',
        onTap: () =>
            profileMessage(context, 'WhatsApp support is not available yet.'),
      ),
      const SizedBox(height: 12),
      const SelectableText(supportEmail),
      TextButton(
        onPressed: () async {
          try {
            await Clipboard.setData(const ClipboardData(text: supportEmail));
            if (mounted) setState(() => _message = 'Email address copied.');
          } catch (_) {
            if (mounted) {
              setState(() => _message = 'Could not copy the email address.');
            }
          }
        },
        child: const Text('Copy email address'),
      ),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
    ],
  );
}

class ProfileFaqsScreen extends StatefulWidget {
  const ProfileFaqsScreen({super.key});
  @override
  State<ProfileFaqsScreen> createState() => _ProfileFaqsScreenState();
}

class _ProfileFaqsScreenState extends State<ProfileFaqsScreen> {
  String _category = 'Getting started';
  String _query = '';
  int? _expanded = 0;
  bool _filterApplied = false;
  static const _categories = [
    'Getting started',
    'Payments',
    'Savings',
    'Family Pocket',
    'Security',
  ];
  static const _items = <({String category, String question, String answer})>[
    (
      category: 'Getting started',
      question: 'How does HealthPocket work?',
      answer: 'HealthPocket helps you plan and save toward health needs. Real funding and healthcare payments are not enabled in this beta.',
    ),
    (
      category: 'Payments',
      question: "Can I pay a provider that isn't a partner?",
      answer: 'The non-partner flow is a preview. No real payment is sent in this beta.',
    ),
    (
      category: 'Savings',
      question: 'How do I add money?',
      answer: 'You can explore the Add Money flow. Live transfers and balance crediting require the payment integration.',
    ),
    (
      category: 'Security',
      question: 'Is my money safe?',
      answer: 'No real funds are held in the current beta. Do not send money to preview account details.',
    ),
    (
      category: 'Family Pocket',
      question: 'How do I invite someone to a Family Pocket?',
      answer: 'Open a Family Pocket and choose Invite. Invitation delivery is still being connected.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = _items
        .asMap()
        .entries
        .where(
          (entry) =>
              (_query.isNotEmpty ||
                  !_filterApplied ||
                  entry.value.category == _category) &&
              ('${entry.value.question} ${entry.value.answer}'
                  .toLowerCase()
                  .contains(_query.toLowerCase())),
        )
        .toList();
    return ProfileV2Scaffold(
      title: 'FAQs',
      subtitle: 'Find quick answers.',
      children: [
        const SizedBox(height: 14),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: ProfileV2.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                '${ProfileV2.assets}4632d.svg',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() {
                    _query = value.trim();
                    _expanded = null;
                  }),
                  decoration: const InputDecoration(
                    hintText: 'Search for help...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final category in _categories)
              ChoiceChip(
                label: Text(category),
                selected: _category == category,
                onSelected: (_) => setState(() {
                  _category = category;
                  _filterApplied = true;
                  _expanded = null;
                }),
                selectedColor: ProfileV2.teal,
                backgroundColor: ProfileV2.soft,
                labelStyle: profileText(
                  12,
                  _category == category ? FontWeight.w600 : FontWeight.w400,
                  _category == category ? Colors.white : ProfileV2.navy,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          ],
        ),
        const SizedBox(height: 34),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No matching help topics.',
              style: profileText(13, FontWeight.w400, ProfileV2.muted),
            ),
          ),
        for (final item in shown)
          InkWell(
            onTap: () => setState(
              () => _expanded = _expanded == item.key ? null : item.key,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ProfileV2.outline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.value.question,
                          style: profileText(
                            14,
                            FontWeight.w600,
                            ProfileV2.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded == item.key
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: ProfileV2.muted,
                        size: 18,
                      ),
                    ],
                  ),
                  if (_expanded == item.key) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.value.answer,
                      style: profileText(
                        12.5,
                        FontWeight.w400,
                        ProfileV2.muted,
                      ).copyWith(height: 1.55),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ProfileTermsScreen extends StatefulWidget {
  const ProfileTermsScreen({super.key, this.initialPrivacy = false});
  final bool initialPrivacy;
  @override
  State<ProfileTermsScreen> createState() => _ProfileTermsScreenState();
}

class _ProfileTermsScreenState extends State<ProfileTermsScreen> {
  late bool _privacy = widget.initialPrivacy;
  @override
  Widget build(BuildContext context) => ProfileV2Scaffold(
    title: _privacy ? 'Privacy Policy' : 'Terms of Service',
    subtitle: 'Draft content · awaiting review',
    children: [
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          _chip('Terms', !_privacy, () => setState(() => _privacy = false)),
          _chip('Privacy', _privacy, () => setState(() => _privacy = true)),
        ],
      ),
      const SizedBox(height: 18),
      if (_privacy) ...[
        _section(
          'Privacy Policy',
          'Placeholder text. Replace with your reviewed Privacy Policy before launch.',
        ),
      ] else ...[
        _section(
          '1. Using HealthPocket',
          'Placeholder text. Replace with your reviewed Terms of Service before launch.',
        ),
        _section(
          '2. Your account',
          'Placeholder text. Describe account responsibilities, PIN security and acceptable use.',
        ),
        _section(
          '3. Payments and balances',
          'Placeholder text. Explain how your balance is used for healthcare payments.',
        ),
      ],
    ],
  );

  Widget _chip(String text, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(text),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: ProfileV2.teal,
    backgroundColor: ProfileV2.soft,
    labelStyle: profileText(
      12,
      selected ? FontWeight.w600 : FontWeight.w400,
      selected ? Colors.white : ProfileV2.navy,
    ),
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  Widget _section(String heading, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: profileText(15, FontWeight.w700, ProfileV2.navy)),
        const SizedBox(height: 6),
        Text(
          body,
          style: profileText(
            12.5,
            FontWeight.w400,
            ProfileV2.muted,
          ).copyWith(height: 1.55),
        ),
      ],
    ),
  );
}
