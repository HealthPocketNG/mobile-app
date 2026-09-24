import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/care/data/mock_non_partner_verification_services.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/non_partner_verification.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum _NonPartnerStep { method, details, review, verifying, result }

class NonPartnerPaymentScreen extends StatefulWidget {
  const NonPartnerPaymentScreen({
    required this.provider,
    this.savingsStore,
    this.accountService = const MockBankAccountVerificationService(),
    this.merchantService = const MockHealthcareMerchantVerificationService(),
    super.key,
  });
  final CareProvider provider;
  final SavingsStore? savingsStore;
  final BankAccountVerificationService accountService;
  final HealthcareMerchantVerificationService merchantService;
  @override
  State<NonPartnerPaymentScreen> createState() =>
      _NonPartnerPaymentScreenState();
}

class _NonPartnerPaymentScreenState extends State<NonPartnerPaymentScreen> {
  final _account = TextEditingController();
  final _amount = TextEditingController();
  var _bankCode = '044';
  var _step = _NonPartnerStep.method;
  ResolvedBankAccount? _recipient;
  MerchantVerificationResult? _verification;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _resolveAccount() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recipient = await widget.accountService.resolveAccount(
        accountNumber: _account.text.trim(),
        bankCode: _bankCode,
      );
      if (mounted) {
        setState(() {
          _recipient = recipient;
          _step = _NonPartnerStep.review;
        });
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We could not resolve this account right now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final recipient = _recipient;
    final amount = int.tryParse(_amount.text.replaceAll(',', ''));
    final balance = widget.savingsStore?.developmentBalanceKobo;
    if (recipient == null || amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid payment amount.');
      return;
    }
    if (balance != null && amount * 100 > balance) {
      setState(
        () => _error =
            'Your HealthPocket balance is not enough for this payment.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _step = _NonPartnerStep.verifying;
    });
    final result = await widget.merchantService.verifyRecipient(
      providerId: widget.provider.id,
      recipient: recipient,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verification = result;
      _step = _NonPartnerStep.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _NonPartnerStep.method => 'Choose Payment Method',
      _NonPartnerStep.details => 'Bank Transfer',
      _NonPartnerStep.review => 'Review Payment',
      _NonPartnerStep.verifying => 'Verifying merchant',
      _NonPartnerStep.result => 'Payment Result',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_step) {
            _NonPartnerStep.method => _method(context),
            _NonPartnerStep.details => _details(context),
            _NonPartnerStep.review => _review(context),
            _NonPartnerStep.verifying => const _VerificationProgress(),
            _NonPartnerStep.result => _result(context),
          },
        ),
      ),
    );
  }

  Widget _providerSummary() => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(LucideIcons.building2, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.provider.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${widget.provider.city}, ${widget.provider.state}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              const Text(
                'Not a partner',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _method(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'How would you like to pay?',
        style: TextStyle(color: AppColors.inkMuted),
      ),
      const SizedBox(height: AppSpacing.md),
      _providerSummary(),
      const SizedBox(height: AppSpacing.lg),
      const _MethodCard(
        icon: LucideIcons.scanQrCode,
        title: 'Scan QR Code',
        subtitle: 'Unavailable for non-partner payments',
        enabled: false,
      ),
      const SizedBox(height: AppSpacing.sm),
      _MethodCard(
        icon: LucideIcons.landmark,
        title: 'Pay via Bank Transfer',
        subtitle: 'Enter the provider’s account details',
        onTap: () => setState(() => _step = _NonPartnerStep.details),
      ),
      const SizedBox(height: AppSpacing.lg),
      const _InfoCard(
        message: 'Payments to non-partners are verified before completion to help ensure HealthPocket funds are used for healthcare.',
      ),
    ],
  );
  Widget _details(BuildContext context) => ListView(
    children: [
      const Text(
        'Enter the provider’s account details.',
        style: TextStyle(color: AppColors.inkMuted),
      ),
      const SizedBox(height: AppSpacing.md),
      _providerSummary(),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        controller: _account,
        keyboardType: TextInputType.number,
        maxLength: 10,
        decoration: const InputDecoration(labelText: 'Account number'),
      ),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<String>(
        initialValue: _bankCode,
        decoration: const InputDecoration(labelText: 'Bank name'),
        items: const [
          DropdownMenuItem(value: '044', child: Text('Access Bank')),
          DropdownMenuItem(value: '058', child: Text('GTBank')),
          DropdownMenuItem(value: '033', child: Text('UBA')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _bankCode = value);
        },
      ),
      const SizedBox(height: AppSpacing.md),
      const _InfoCard(
        message: 'We’ll verify this account to make sure it’s a healthcare provider.',
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      const SizedBox(height: AppSpacing.lg),
      AppPrimaryButton(
        label: 'Continue  →',
        isLoading: _busy,
        onPressed: _busy ? null : _resolveAccount,
      ),
    ],
  );
  Widget _review(BuildContext context) {
    final recipient = _recipient!;
    final balance = widget.savingsStore?.developmentBalanceKobo;
    return ListView(
      children: [
        const Text(
          'Confirm the details before you pay.',
          style: TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        _providerSummary(),
        const SizedBox(height: AppSpacing.lg),
        _ReviewRow(label: 'Account number', value: recipient.accountNumber),
        _ReviewRow(label: 'Bank name', value: recipient.bankName),
        _ReviewRow(label: 'Account name', value: recipient.accountName),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (NGN)',
            prefixText: '₦ ',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ReviewRow(
          label: 'Paying from',
          value: balance == null
              ? 'HealthPocket Balance'
              : 'HealthPocket Balance · ₦${balance ~/ 100}',
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Verify recipient  →',
          isLoading: _busy,
          onPressed: _busy ? null : _verify,
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final result = _verification!;
    final success = result.verified;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: success ? AppColors.primary : AppColors.secondary,
          child: Icon(
            success ? LucideIcons.check : LucideIcons.x,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          success ? 'Recipient verified' : 'Verification failed',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.reason,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (success)
          const _InfoCard(
            message: 'Beta verification completed. No bank transfer or balance movement has been performed.',
          ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: success ? 'Done' : 'Edit account details',
          onPressed: () {
            if (success) {
              Navigator.pop(context);
            } else {
              setState(() => _step = _NonPartnerStep.details);
            }
          },
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : .55,
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.info, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.inkMuted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _VerificationProgress extends StatelessWidget {
  const _VerificationProgress();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpacing.lg),
        Text(
          'Checking if this provider is a healthcare business...',
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.lg),
        _InfoCard(
          message: 'Valid account details\nChecking merchant category\nConfirming healthcare provider\nSecuring your payment',
        ),
      ],
    ),
  );
}
