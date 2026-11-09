import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_common.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_final_pages.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_closing_pages.dart';

const supportEmail = 'gethealthpocket@gmail.com';

Uri supportEmailUri() => Uri(
  scheme: 'mailto',
  path: supportEmail,
  query:
      {
            'subject': 'HealthPocket beta feedback / support',
            'body': 'What were you trying to do?\n\nWhat happened?\n\nWhat did you expect?\n\nPhone model and app version (optional):\n\nPlease do not include passwords, PINs, banking details, or medical records.',
          }.entries
          .map(
            (entry) =>
                '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
          )
          .join('&'),
);

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.openEmail});
  final Future<bool> Function(Uri)? openEmail;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _query = '';

  void _contact() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProfileContactSupportScreen(openEmail: widget.openEmail),
    ),
  );

  void _faq() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const ProfileFaqsScreen()),
  );

  void _report() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProfileReportIssueScreen(openEmail: widget.openEmail),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final entries = <_SupportEntry>[
      _SupportEntry('a4948.svg', 'FAQs', 'Find quick answers', _faq),
      _SupportEntry(
        'b20cf.svg',
        'Contact Support',
        'Get in touch with our team',
        _contact,
      ),
      _SupportEntry(
        '36984.svg',
        'Report an Issue',
        'Let us know what went wrong',
        _report,
        const Color(0xFFFFEBC8),
      ),
      _SupportEntry(
        '04e6c.svg',
        'App Guides',
        'Learn how to use HealthPocket',
        () => profileMessage(context, 'App guides are coming soon.'),
      ),
      _SupportEntry(
        'b6aab.svg',
        'Terms & Privacy',
        'Read our policies',
        () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const ProfileTermsScreen()),
        ),
        const Color(0xFFFFEBC8),
      ),
    ];
    final shown = entries
        .where(
          (entry) => '${entry.title} ${entry.subtitle}'.toLowerCase().contains(
            _query.trim().toLowerCase(),
          ),
        )
        .toList();
    return ProfileV2Scaffold(
      title: 'Help & Support',
      subtitle: "We're here to help.",
      backAsset: 'f299b.svg',
      children: [
        const SizedBox(height: 22),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProfileV2.outline),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                '${ProfileV2.assets}4632d.svg',
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
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
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No matching help topics.',
              style: profileText(13, FontWeight.w400, ProfileV2.muted),
            ),
          ),
        for (final entry in shown)
          ProfileV2CardRow(
            asset: entry.asset,
            title: entry.title,
            subtitle: entry.subtitle,
            background: entry.background,
            onTap: entry.onTap,
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF9F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ProfileV2Icon(
                    asset: 'e616f.svg',
                    background: Colors.white,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still need help?',
                          style: profileText(
                            15,
                            FontWeight.w600,
                            ProfileV2.teal,
                          ),
                        ),
                        Text(
                          'Our team is always happy to assist you.',
                          style: profileText(
                            12,
                            FontWeight.w400,
                            ProfileV2.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _contact,
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileV2.teal,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Contact Support'),
                    const SizedBox(width: 10),
                    SvgPicture.asset(
                      '${ProfileV2.assets}4695b.svg',
                      width: 20,
                      height: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportEntry {
  const _SupportEntry(
    this.asset,
    this.title,
    this.subtitle,
    this.onTap, [
    this.background = ProfileV2.mint,
  ]);
  final String asset, title, subtitle;
  final VoidCallback onTap;
  final Color background;
}
