import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/demo_care_request.dart';

class DemoCareJourneyScreen extends StatefulWidget {
  const DemoCareJourneyScreen({required this.providers, super.key});
  final List<CareProvider> providers;
  @override
  State<DemoCareJourneyScreen> createState() => _DemoCareJourneyScreenState();
}

class _DemoCareJourneyScreenState extends State<DemoCareJourneyScreen> {
  final _code = TextEditingController();
  final _amount = TextEditingController();
  CareProvider? _provider;
  String? _error;
  final List<DemoCareRequest> _requests = [];
  bool _submitting = false;
  @override
  void dispose() {
    _code.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _validate(String raw) {
    final id = parseDemoProviderQr(raw);
    final matches = widget.providers.where((p) => p.isDemo && p.id == id);
    setState(() {
      _provider = matches.firstOrNull;
      _error = _provider == null
          ? 'Unrecognized demo QR. No request was created.'
          : null;
    });
  }

  Future<void> _submit() async {
    final provider = _provider;
    final kobo = parseCareAmount(_amount.text);
    if (provider == null || kobo == null) {
      setState(
        () => _error = 'Select a demo provider and enter an amount from ₦0.01 to ₦1,000,000 (up to two decimals).',
      );
      return;
    }
    setState(() => _submitting = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review simulated request'),
        content: Text(
          '${provider.name}\n₦${(kobo / 100).toStringAsFixed(2)}\n\nNo money will move. This does not authorize real treatment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create simulation'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (confirmed == true) {
        _requests.add(
          DemoCareRequest(
            id: 'DEMO-${_requests.length + 1}',
            providerName: provider.name,
            amountKobo: kobo,
          ),
        );
        _amount.clear();
        _provider = null;
        _code.clear();
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demo care requests')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'SIMULATION ONLY — no money, care entitlement, or real settlement. Requests stay on this screen only and are discarded when you leave. Not a shared partner portal.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting
              ? null
              : () async {
                  final raw = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const _ScanDemoQr()),
                  );
                  if (mounted && raw != null) {
                    _code.text = raw;
                    _validate(raw);
                  }
                },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan demo provider QR'),
        ),
        const Text('Camera unavailable? Paste a demo QR payload below.'),
        TextField(
          controller: _code,
          enabled: !_submitting,
          decoration: const InputDecoration(labelText: 'Demo QR payload'),
          onChanged: (_) => setState(() => _provider = null),
        ),
        TextButton(
          onPressed: _submitting ? null : () => _validate(_code.text),
          child: const Text('Check code'),
        ),
        ExpansionTile(
          title: const Text('Sample payloads for testing'),
          children: widget.providers
              .where((p) => p.isDemo)
              .map(
                (p) => ListTile(
                  title: Text(p.name),
                  subtitle: SelectableText(
                    'healthpocket-demo:provider:${p.id}',
                  ),
                  trailing: TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            _code.text = 'healthpocket-demo:provider:${p.id}';
                            _validate(_code.text);
                          },
                    child: const Text('Use'),
                  ),
                ),
              )
              .toList(),
        ),
        if (_provider != null) Text('Provider: ${_provider!.name}'),
        TextField(
          controller: _amount,
          enabled: !_submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Simulated amount (NGN)',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Review request'),
        ),
        const SizedBox(height: 24),
        const Text('Requests in this demo session'),
        if (_requests.isEmpty) const Text('No requests yet.'),
        ..._requests.reversed.map(
          (request) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${request.id} • ${request.providerName}'),
                  Text(
                    '₦${(request.amountKobo / 100).toStringAsFixed(2)} • SIMULATED ${request.status.label}',
                  ),
                  const Text(
                    'Not proof of payment or authorization for real care.',
                  ),
                  ...request.events.map(
                    (event) =>
                        Text('${event.$1.label} — ${event.$2.toLocal()}'),
                  ),
                  if (request.status == CareRequestStatus.requested)
                    TextButton(
                      onPressed: () => setState(request.cancel),
                      child: const Text('Cancel request'),
                    ),
                  if (request.status.index < CareRequestStatus.settled.index)
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _DemoOperator(request: request),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      child: const Text('Open DEV operator simulator'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DemoOperator extends StatefulWidget {
  const _DemoOperator({required this.request});
  final DemoCareRequest request;
  @override
  State<_DemoOperator> createState() => _DemoOperatorState();
}

class _DemoOperatorState extends State<_DemoOperator> {
  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('DEV operator simulator')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Role-play only. You are not signed in as a real partner or administrator. No balances are reserved or debited.',
          ),
          Text('${request.id} • ${request.providerName}'),
          Text('SIMULATED ${request.status.label}'),
          if (request.status.index < CareRequestStatus.settled.index)
            FilledButton(
              onPressed: () => setState(() => request.advance(request.status)),
              child: Text(
                'Simulate: ${CareRequestStatus.values[request.status.index + 1].label}',
              ),
            ),
          if (request.status == CareRequestStatus.settled)
            const Text('Simulation complete. No actual settlement occurred.'),
        ],
      ),
    );
  }
}

class _ScanDemoQr extends StatefulWidget {
  const _ScanDemoQr();
  @override
  State<_ScanDemoQr> createState() => _ScanDemoQrState();
}

class _ScanDemoQrState extends State<_ScanDemoQr> {
  bool _handled = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan demo QR')),
    body: MobileScanner(
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
            'Camera unavailable or permission denied. Go back and paste a demo QR payload instead.',
          ),
        ),
      ),
    ),
  );
}
