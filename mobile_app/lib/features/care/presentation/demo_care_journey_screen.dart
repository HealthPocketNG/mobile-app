import 'package:flutter/material.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/widgets/healthpocket_state_view.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/demo_care_request.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const demoCareNotice = 'Beta demonstration only — no money will move.';

enum _PaymentStep {
  amount,
  insufficientBalance,
  scan,
  confirm,
  processing,
  result,
}

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
  _PaymentStep _step = _PaymentStep.amount;
  bool _submitting = false;
  int? _insufficientAmountKobo;

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

  void _resolve(String payload) {
    final result = _session!.resolve(payload);
    setState(
      () => _step = result.status == DemoAuthorizationStatus.created
          ? _PaymentStep.confirm
          : _PaymentStep.result,
    );
  }

  Future<void> _confirmPayment() async {
    if (_submitting || _session == null) return;
    setState(() {
      _submitting = true;
      _step = _PaymentStep.processing;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _step = _PaymentStep.result;
    });
  }

  int? get _availableBalanceKobo => widget.savingsStore?.developmentBalanceKobo;

  String _formatKobo(int value) => '₦${(value / 100).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final result = session?.result;
    final step = _step;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (step) {
          _PaymentStep.amount => 'Enter Amount',
          _PaymentStep.insufficientBalance => 'Insufficient Balance',
          _PaymentStep.scan => 'Scan QR Code',
          _PaymentStep.confirm => 'Confirm Payment',
          _PaymentStep.processing => 'Processing Payment',
          _PaymentStep.result => 'Payment Result',
        }),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            demoCareNotice,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(provider.name, style: Theme.of(context).textTheme.titleLarge),
          Text('Demo provider ID: ${provider.id}'),
          if (session != null)
            Text('Amount: ₦${(session.amountKobo / 100).toStringAsFixed(2)}'),
          const SizedBox(height: 20),
          if (step == _PaymentStep.result && result != null) ...[
            Semantics(liveRegion: true, child: Text(result.message)),
            Text('Status: ${_statusLabel(result.status)}'),
            if (result.reference != null)
              SelectableText('Reference: ${result.reference}'),
            const SizedBox(height: 12),
            _ResultMessage(result: result),
            AppPrimaryButton(
              label: result.status == DemoAuthorizationStatus.created
                  ? 'View Receipt'
                  : 'Back to centre',
              onPressed: () => Navigator.pop(context),
            ),
            if (result.status == DemoAuthorizationStatus.rejected)
              TextButton(
                onPressed: () => setState(() {
                  _session?.clear();
                  _step = _PaymentStep.scan;
                }),
                child: const Text('Scan Again'),
              ),
          ] else if (step == _PaymentStep.insufficientBalance) ...[
            InsufficientBalanceView(
              paymentAmountKobo: _insufficientAmountKobo ?? 0,
              availableBalanceKobo: _availableBalanceKobo ?? 0,
              onChooseDifferentAmount: () => setState(() {
                _insufficientAmountKobo = null;
                _step = _PaymentStep.amount;
              }),
            ),
          ] else if (step == _PaymentStep.amount) ...[
            const Text(
              'Enter Amount',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (NGN)',
                helperText: '₦0.01–₦1,000,000; up to two decimal places',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children:
                  [500, 1000, 2000, 5000, 10000]
                      .map(
                        (amount) => _AmountPreset(
                          label: _formatKobo(amount * 100),
                          onTap: () =>
                              setState(() => _amount.text = amount.toString()),
                        ),
                      )
                      .toList()
                    ..add(const _AmountPreset(label: 'Other')),
            ),
            const SizedBox(height: AppSpacing.md),
            _BalanceCard(balanceKobo: _availableBalanceKobo),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            AppPrimaryButton(
              label: 'Confirm amount and continue to scan',
              onPressed: () {
                final kobo = parseCareAmount(_amount.text);
                if (kobo == null) {
                  setState(
                    () => _error =
                        'Enter a valid positive amount within the limit.',
                  );
                  return;
                }
                final available = _availableBalanceKobo;
                if (available != null && kobo > available) {
                  setState(() {
                    _error = null;
                    _insufficientAmountKobo = kobo;
                    _step = _PaymentStep.insufficientBalance;
                  });
                  return;
                }
                setState(() {
                  _error = null;
                  _session = DemoAuthorizationSession(
                    providers: widget.providers,
                    selectedProviderId: provider.id,
                    amountKobo: kobo,
                  );
                  _step = _PaymentStep.scan;
                });
              },
            ),
          ] else if (step == _PaymentStep.scan) ...[
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
                  onPressed: () => _resolve('hp://provider/wrong_partner_999'),
                  child: const Text('Scan unknown provider'),
                ),
                TextButton(
                  onPressed: () => _resolve('invalid'),
                  child: const Text('Scan malformed code'),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() {
                session!.cancel();
                _step = _PaymentStep.result;
              }),
              child: const Text('Cancel scan'),
            ),
          ] else if (step == _PaymentStep.confirm) ...[
            _ConfirmationCard(session: session!),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Confirm Payment  →',
              isLoading: _submitting,
              onPressed: _submitting ? null : _confirmPayment,
            ),
          ] else ...[
            const _ProcessingPaymentView(),
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

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.session});
  final DemoAuthorizationSession session;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.outline),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Payment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'PAY TO',
          style: TextStyle(
            color: AppColors.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          session.selectedProvider.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          '${session.selectedProvider.city}, ${session.selectedProvider.state}',
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const Divider(height: AppSpacing.xl),
        const Text(
          'AMOUNT',
          style: TextStyle(
            color: AppColors.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '₦${(session.amountKobo / 100).toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Divider(height: AppSpacing.xl),
        const Text(
          'FROM',
          style: TextStyle(
            color: AppColors.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'HealthPocket Balance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ProcessingPaymentView extends StatelessWidget {
  const _ProcessingPaymentView();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxl),
    child: Column(
      children: [
        const SizedBox(
          height: 52,
          width: 52,
          child: CircularProgressIndicator(strokeWidth: 5),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Processing Payment',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Please wait while we complete your payment...',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.shieldCheck, color: AppColors.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your payment is secure',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ResultMessage extends StatelessWidget {
  const _ResultMessage({required this.result});
  final DemoAuthorizationResult result;
  @override
  Widget build(BuildContext context) {
    final success = result.status == DemoAuthorizationStatus.created;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: success ? AppColors.primarySoft : AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: success ? AppColors.primary : AppColors.secondary,
            child: Icon(
              success ? LucideIcons.check : LucideIcons.x,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            success ? 'Payment Successful!' : "Payment couldn't be completed.",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Beta demonstration only — No payment was processed, no money moved and no provider was settled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

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
              const Text(
                'Your Balance',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
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
        const Text(
          'Top Up ›',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
  final _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan to Pay'),
      actions: [
        IconButton(
          tooltip: 'Toggle flash',
          onPressed: _controller.toggleTorch,
          icon: const Icon(LucideIcons.zap),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel scan'),
        ),
      ],
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
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
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Wrap(
            children: [
              const Text(
                'Enter partner code',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'healthpocket://pay?providerId=...',
                ),
              ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.pop(context, controller.text),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (payload != null && context.mounted) Navigator.pop(context, payload);
  }
}
