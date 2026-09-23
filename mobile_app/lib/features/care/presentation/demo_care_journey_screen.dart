import 'package:flutter/material.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/demo_care_request.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const demoCareNotice = 'Beta demonstration only — no money will move.';

class DemoCareJourneyScreen extends StatefulWidget {
  const DemoCareJourneyScreen({
    required this.providers,
    required this.selectedProviderId,
    this.savingsStore,
    super.key,
  });
  final List<CareProvider> providers;
  final String selectedProviderId;
  final SavingsStore? savingsStore;

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

  int? get _availableBalanceKobo => widget.savingsStore?.developmentBalanceKobo;

  String _formatKobo(int value) => '₦${(value / 100).toStringAsFixed(0)}';

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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(demoCareNotice, style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
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
            const Text('Enter Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (NGN)',
                helperText: '₦0.01–₦1,000,000; up to two decimal places',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [500, 1000, 2000, 5000, 10000]
                  .map(
                    (amount) => _AmountPreset(
                      label: _formatKobo(amount * 100),
                      onTap: () => setState(() => _amount.text = amount.toString()),
                    ),
                  )
                  .toList()
                ..add(const _AmountPreset(label: 'Other')),
            ),
            const SizedBox(height: AppSpacing.md),
            _BalanceCard(balanceKobo: _availableBalanceKobo),
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
                final available = _availableBalanceKobo;
                if (available != null && kobo > available) {
                  setState(() => _error = 'Your HealthPocket balance is not enough for this payment.');
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

class _AmountPreset extends StatelessWidget {
  const _AmountPreset({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 98,
    child: Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceKobo});
  final int? balanceKobo;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.walletCards, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Balance', style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              Text(
                balanceKobo == null
                    ? 'Balance unavailable'
                    : '₦${(balanceKobo! / 100).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Text('Top Up ›', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ],
    ),
  );
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
        appBar: AppBar(
          title: const Text('Scan to Pay'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel scan'),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
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
                      'Camera unavailable or permission denied. Enter the partner code instead.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            const Positioned(
              top: 28,
              left: 28,
              right: 28,
              child: Text(
                'Point your camera at the HealthPocket QR code at the counter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            Center(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: () => _enterCode(context),
                icon: const Icon(LucideIcons.keyboard),
                label: const Text('Enter code instead'),
              ),
            ),
          ],
        ),
      );

  Future<void> _enterCode(BuildContext context) async {
    final controller = TextEditingController();
    final payload = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Wrap(children: [
            const Text('Enter partner code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'healthpocket://pay?providerId=...')),
            const SizedBox(height: 16),
            AppPrimaryButton(label: 'Continue', onPressed: () => Navigator.pop(context, controller.text)),
          ]),
        ),
      ),
    );
    controller.dispose();
    if (payload != null && mounted) Navigator.pop(context, payload);
  }
}
