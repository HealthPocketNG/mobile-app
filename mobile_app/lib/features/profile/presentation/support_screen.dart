import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _opening = false;
  String? _message;

  Future<void> _email() async {
    setState(() {
      _opening = true;
      _message = null;
    });
    try {
      final uri = supportEmailUri();
      final opened = await (widget.openEmail?.call(uri) ?? launchUrl(uri));
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
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & feedback')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Help us improve HealthPocket',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const Text(
          'Tell us what you tried, what happened, and what you expected. Include your phone model and app version if helpful. You can also share feedback in the private beta WhatsApp group you joined.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Never share your password, app PIN, banking details, or medical records. Remove personal information from screenshots before sharing.',
        ),
        const SizedBox(height: 16),
        const Text(
          'This inbox is for app support and feedback, not urgent medical assistance.',
        ),
        const SizedBox(height: 24),
        const SelectableText(supportEmail),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _opening ? null : _email,
          icon: const Icon(Icons.email_outlined),
          label: Text(_opening ? 'Opening…' : 'Open email app'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Clipboard.setData(const ClipboardData(text: supportEmail));
              if (mounted) setState(() => _message = 'Email address copied.');
            } catch (_) {
              if (mounted) {
                setState(
                  () => _message = 'Could not copy. Select the email address above to copy it manually.',
                );
              }
            }
          },
          child: const Text('Copy email address'),
        ),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
      ],
    ),
  );
}
