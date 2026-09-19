import 'package:flutter/material.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/demo_care_request.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const demoCareNotice = 'Beta demonstration only — no money will move.';

class DemoCareJourneyScreen extends StatefulWidget {
  const DemoCareJourneyScreen({
    required this.providers,
    required this.selectedProviderId,
    super.key,
  });
  final List<CareProvider> providers;
  final String selectedProviderId;

  @override
  State<DemoCareJourneyScreen> createState() => _DemoCareJourneyScreenState();
}

class _DemoCareJourneyScreenState extends State<DemoCareJourneyScreen> {
  final _amount = TextEditingController();
  final _payload = TextEditingController();
  DemoAuthorizationSession? _session;
  String? _error;
  bool _openingScanner = false;

  CareProvider get provider => widget.providers.firstWhere(
        (item) => item.id == widget.selectedProviderId && item.isDemo,
      );

  @override
  void dispose() {
    _session?.clear();
    _amount.dispose();
    _payload.dispose();
    super.dispose();
  }

  void _resolve(String payload) => setState(() => _session!.resolve(payload));

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final result = session?.result;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          result != null
              ? 'Demo result'
              : session == null
                  ? 'Enter amount'
                  : 'Scan to pay — demo',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(demoCareNotice,
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(provider.name, style: Theme.of(context).textTheme.titleLarge),
          Text('Demo provider ID: ${provider.id}'),
          if (session != null)
            Text('Amount: ₦${(session.amountKobo / 100).toStringAsFixed(2)}'),
          const SizedBox(height: 20),
          if (result != null) ...[
            Semantics(liveRegion: true, child: Text(result.message)),
            Text('Status: ${_statusLabel(result.status)}'),
            if (result.reference != null)
              SelectableText('Reference: ${result.reference}'),
            const SizedBox(height: 12),
            const Text(
              'This is a beta design flow. No payment was processed and no provider has been settled. This is not evidence of funds or permission to receive treatment.',
            ),
            AppPrimaryButton(
              label: 'Back to centre',
              onPressed: () => Navigator.pop(context),
            ),
          ] else if (session == null) ...[
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (NGN)',
                helperText: '₦0.01–₦1,000,000; up to two decimal places',
              ),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            AppPrimaryButton(
              label: 'Confirm amount and continue to scan',
              onPressed: () {
                final kobo = parseCareAmount(_amount.text);
                if (kobo == null) {
                  setState(() => _error =
                      'Enter a valid positive amount within the limit.');
                  return;
                }
                setState(() {
                  _error = null;
                  _session = DemoAuthorizationSession(
                    providers: widget.providers,
                    selectedProviderId: provider.id,
                    amountKobo: kobo,
                  );
                });
              },
            ),
          ] else ...[
            const Text(
              'Confirm the centre and amount above, then scan its demo QR. You can also use the mock scanner options below.',
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Open camera scanner'),
              onPressed: _openingScanner
                  ? null
                  : () async {
                      setState(() => _openingScanner = true);
                      final raw = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (_) => const _ScanDemoQr()),
                      );
                      if (!mounted) return;
                      setState(() => _openingScanner = false);
                      if (raw != null) _resolve(raw);
                    },
            ),
            TextField(
              controller: _payload,
              decoration: const InputDecoration(labelText: 'Mock QR payload'),
            ),
            AppPrimaryButton(
              label: 'Resolve demo QR',
              onPressed: () => _resolve(_payload.text),
            ),
            ExpansionTile(
              title: const Text('Mock scanner test options'),
              children: [
                for (final item in widget.providers)
                  TextButton(
                    onPressed: () => _resolve('hp://provider/${item.id}'),
                    child: Text('Scan ${item.name}'),
                  ),
                TextButton(
                  onPressed: () =>
                      _resolve('hp://provider/wrong_partner_999'),
                  child: const Text('Scan unknown provider'),
                ),
                TextButton(
                  onPressed: () => _resolve('invalid'),
                  child: const Text('Scan malformed code'),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => session.cancel()),
              child: const Text('Cancel scan'),
            ),
          ],
        ],
      ),
    );
  }
}

String _statusLabel(DemoAuthorizationStatus status) => switch (status) {
      DemoAuthorizationStatus.created => 'DemoAuthorizationCreated',
      DemoAuthorizationStatus.rejected => 'DemoRejected',
      DemoAuthorizationStatus.cancelled => 'DemoCancelled',
      DemoAuthorizationStatus.expired => 'DemoExpired',
    };

class _ScanDemoQr extends StatefulWidget {
  const _ScanDemoQr();
  @override
  State<_ScanDemoQr> createState() => _ScanDemoQrState();
}

class _ScanDemoQrState extends State<_ScanDemoQr> {
  bool _handled = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan demo QR'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel scan'),
            ),
          ],
        ),
        body: Column(
          children: [
            const Text(demoCareNotice),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (_handled || raw == null) return;
                  _handled = true;
                  Navigator.pop(context, raw);
                },
                errorBuilder: (context, error) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Camera unavailable or permission denied. Go back to use mock scanner options.',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
