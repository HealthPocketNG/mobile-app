import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/widgets/healthpocket_state_view.dart';
import 'package:healthpocket/features/care/data/mock_non_partner_verification_services.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/domain/non_partner_verification.dart';
import 'package:healthpocket/features/care/presentation/care_v2_bank_selection.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';
import 'package:healthpocket/features/care/presentation/care_v2_explanation_sheet.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _NonPartnerStep {
  amount,
  details,
  review,
  insufficientBalance,
  verifying,
  result,
}

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
  final _amount = TextEditingController(text: '5000');
  var _bankCode = '044';
  var _step = _NonPartnerStep.amount;
  ResolvedBankAccount? _recipient;
  MerchantVerificationResult? _verification;
  String? _error;
  bool _busy = false;
  int? _insufficientAmountKobo;

  int get _amountKobo =>
      (int.tryParse(_amount.text.replaceAll(',', '')) ?? 0) * 100;
  int get _balanceKobo => widget.savingsStore?.developmentBalanceKobo ?? 0;

  void _selectAmount(int amount) => setState(() {
    _amount.text = amount.toString();
    _error = null;
  });

  Future<void> _customAmount() async {
    var draft = _amount.text;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Other amount'),
        content: TextFormField(
          initialValue: draft,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₦ '),
          onChanged: (value) => draft = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(draft.replaceAll(',', ''));
              if (value == null || value < 1 || value > 1000000) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Use amount'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) _selectAmount(selected);
  }

  void _continueFromAmount() {
    if (_amountKobo < 100 || _amountKobo > 100000000) {
      setState(() => _error = 'Enter an amount from ₦1 to ₦1,000,000.');
      return;
    }
    setState(() {
      _error = null;
      _step = _NonPartnerStep.details;
    });
  }

  Future<void> _chooseBank() async {
    final selected = await Navigator.push<CareBankOption>(
      context,
      MaterialPageRoute(
        builder: (_) => CareV2BankSelection(selectedCode: _bankCode),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _bankCode = selected.code;
        _recipient = null;
        _error = null;
      });
    }
  }

  String get _bankName =>
      carePreviewBanks.where((bank) => bank.code == _bankCode).first.name;
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
      setState(() {
        _error = null;
        _insufficientAmountKobo = amount * 100;
        _step = _NonPartnerStep.insufficientBalance;
      });
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
    if (_step == _NonPartnerStep.amount) return _amountScreen();
    if (_step == _NonPartnerStep.details) return _details(context);
    if (_step == _NonPartnerStep.review) return _review(context);
    final title = switch (_step) {
      _NonPartnerStep.amount => 'Enter Amount',
      _NonPartnerStep.details => 'Bank Transfer',
      _NonPartnerStep.review => 'Review Payment',
      _NonPartnerStep.insufficientBalance => 'Insufficient Balance',
      _NonPartnerStep.verifying => 'Verifying merchant',
      _NonPartnerStep.result => 'Payment Result',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_step) {
            _NonPartnerStep.amount => _amountScreen(),
            _NonPartnerStep.details => _details(context),
            _NonPartnerStep.review => _review(context),
            _NonPartnerStep.insufficientBalance => InsufficientBalanceView(
              paymentAmountKobo: _insufficientAmountKobo ?? 0,
              availableBalanceKobo:
                  widget.savingsStore?.developmentBalanceKobo ?? 0,
              onChooseDifferentAmount: () => setState(() {
                _insufficientAmountKobo = null;
                _step = _NonPartnerStep.amount;
              }),
            ),
            _NonPartnerStep.verifying => const _VerificationProgress(),
            _NonPartnerStep.result => _result(context),
          },
        ),
      ),
    );
  }

  Widget _amountScreen() => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            CareV2Back(
              asset: 'amount-16de2.svg',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            CareProviderSummaryV2(
              provider: widget.provider,
              badgeAsset: 'amount-c11d5.svg',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CareV2.outline),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x150F1B4C),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Amount',
                    style: careText(14, FontWeight.w700, CareV2.navy),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      careMoney(_amountKobo),
                      style: careText(40, FontWeight.w700, CareV2.navy),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Enter the amount you want to pay at ${widget.provider.name}.',
                    style: careText(12, FontWeight.w400, CareV2.muted),
                  ),
                  const SizedBox(height: 16),
                  for (final row in const [
                    [500, 1000, 2000],
                    [5000, 10000, 0],
                  ]) ...[
                    Row(
                      children: [
                        for (var index = 0; index < row.length; index++) ...[
                          if (index > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _AmountChoice(
                              label: row[index] == 0
                                  ? 'Other'
                                  : careMoney(row[index] * 100)
                                        .replaceFirst('₦ ', '₦'),
                              selected: row[index] * 100 == _amountKobo,
                              onTap: () => row[index] == 0
                                  ? _customAmount()
                                  : _selectAmount(row[index]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF9F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CareV2.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SvgPicture.asset(
                      '${CareV2.assets}amount-cefb9.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Balance',
                          style: careText(11, FontWeight.w400, CareV2.muted),
                        ),
                        Text(
                          careMoney(_balanceKobo),
                          style: careText(18, FontWeight.w700, CareV2.teal),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/savings/add-money'),
                    child: Row(
                      children: [
                        Text(
                          'Top Up',
                          style: careText(12, FontWeight.w500, CareV2.teal),
                        ),
                        const SizedBox(width: 4),
                        SvgPicture.asset(
                          '${CareV2.assets}amount-5fc97.svg',
                          width: 14,
                          height: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: careText(12, FontWeight.w400, Colors.red)),
            ],
            const SizedBox(height: 10),
            Text(
              'Demo walkthrough only. No money will move.',
              style: careText(11, FontWeight.w400, CareV2.muted),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: CareV2Button(
            label: 'Continue',
            arrowAsset: 'amount-ed152.svg',
            onPressed: _continueFromAmount,
          ),
        ),
      ),
    ),
  );
  Widget _details(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        children: [
          CareV2Back(
            asset: 'account-16de2.svg',
            onTap: () => setState(() => _step = _NonPartnerStep.amount),
          ),
          const SizedBox(height: 6),
          Text(
            'Bank Transfer',
            style: careText(26, FontWeight.w700, CareV2.teal),
          ),
          const SizedBox(height: 2),
          Text(
            "Enter the provider's account details.",
            style: careText(13, FontWeight.w400, CareV2.muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF9F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CareProviderAvatarV2(provider: widget.provider, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.provider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: careText(14, FontWeight.w600, CareV2.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Not a partner',
                        style: careText(11, FontWeight.w400, CareV2.muted),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${widget.provider.city}, ${widget.provider.state}',
                        style: careText(12, FontWeight.w400, CareV2.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Account number',
            style: careText(12, FontWeight.w600, CareV2.navy),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: TextField(
              controller: _account,
              keyboardType: TextInputType.number,
              maxLength: 10,
              onChanged: (_) => setState(() {
                _recipient = null;
                _error = null;
              }),
              style: careText(14, FontWeight.w400, CareV2.navy),
              decoration: InputDecoration(
                counterText: '',
                hintText: '10-digit account number',
                hintStyle: careText(14, FontWeight.w400, CareV2.muted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SvgPicture.asset(
                    '${CareV2.assets}account-b334d.svg',
                    width: 20,
                    height: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CareV2.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _error == null
                        ? CareV2.outline
                        : const Color(0xFFE8405F),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _error == null
                        ? CareV2.teal
                        : const Color(0xFFE8405F),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  '${CareV2.assets}account-2436d.svg',
                  width: 25,
                  height: 30,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: careText(
                      12,
                      FontWeight.w400,
                      const Color(0xFFE8405F),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text('Bank name', style: careText(12, FontWeight.w600, CareV2.navy)),
          const SizedBox(height: 4),
          InkWell(
            onTap: _chooseBank,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: CareV2.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _bankName,
                      style: careText(14, FontWeight.w400, CareV2.navy),
                    ),
                  ),
                  SvgPicture.asset(
                    '${CareV2.assets}account-8d287.svg',
                    width: 18,
                    height: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Account name',
            style: careText(12, FontWeight.w600, CareV2.navy),
          ),
          const SizedBox(height: 4),
          Container(
            height: 52,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: CareV2.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _recipient?.accountName ?? 'Account name will show here',
              style: careText(14, FontWeight.w400, CareV2.muted),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF9F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  '${CareV2.assets}transfer-348c3.svg',
                  width: 14,
                  height: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "We'll verify this account to make sure it's a healthcare provider.",
                    style: careText(
                      12,
                      FontWeight.w400,
                      CareV2.muted,
                    ).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: CareV2Button(
          label: 'Continue',
          arrowAsset: 'account-ed152.svg',
          onPressed: _busy || _error != null ? null : _resolveAccount,
        ),
      ),
    ),
  );
  Widget _review(BuildContext context) {
    final recipient = _recipient!;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              CareV2Back(
                asset: 'review-86655.svg',
                onTap: () => setState(() => _step = _NonPartnerStep.details),
              ),
              const SizedBox(height: 8),
              Text(
                'Review Payment',
                style: careText(26, FontWeight.w700, CareV2.teal),
              ),
              const SizedBox(height: 3),
              Text(
                'Confirm the details before you pay.',
                style: careText(13, FontWeight.w400, CareV2.muted),
              ),
              const SizedBox(height: 20),
              CareProviderSummaryV2(
                provider: widget.provider,
                badgeAsset: 'review-e0188.svg',
                highlighted: true,
              ),
              const SizedBox(height: 16),
              _ReviewCard(
                children: [
                  _ReviewRow(
                    label: 'Account number',
                    value: recipient.accountNumber,
                    asset: 'review-399f6.svg',
                  ),
                  _ReviewRow(label: 'Bank name', value: recipient.bankName),
                  _ReviewRow(
                    label: 'Account name',
                    value: recipient.accountName,
                    last: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: careText(12, FontWeight.w400, CareV2.muted),
                        ),
                        Text(
                          careMoney(_amountKobo),
                          style: careText(26, FontWeight.w700, CareV2.navy),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit amount',
                    onPressed: () =>
                        setState(() => _step = _NonPartnerStep.amount),
                    icon: SvgPicture.asset(
                      '${CareV2.assets}review-7c667.svg',
                      width: 22,
                      height: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ReviewCard(
                children: [
                  const _ReviewRow(
                    label: 'Paying from',
                    value: 'HealthPocket Balance',
                  ),
                  _ReviewRow(
                    label: 'Balance',
                    value: careMoney(_balanceKobo),
                    last: true,
                    teal: true,
                  ),
                ],
              ),
              const SizedBox(height: 36),
              _Notice(
                message: 'This merchant will be verified as a healthcare provider before the payment is completed.',
                action: () =>
                    showCareExplanationSheet(context, verification: true),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: careText(12, FontWeight.w400, Colors.red)),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: CareV2Button(
              label: 'Pay ${careMoney(_amountKobo)}',
              arrowAsset: 'review-ed152.svg',
              onPressed: _busy ? null : _verify,
            ),
          ),
        ),
      ),
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

class _AmountChoice extends StatelessWidget {
  const _AmountChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? CareV2.teal : CareV2.mint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: careText(
            14,
            selected ? FontWeight.w700 : FontWeight.w500,
            selected ? Colors.white : CareV2.teal,
          ),
        ),
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: CareV2.outline),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: children),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.action});
  final String message;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: CareV2.soft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          '${CareV2.assets}review-7817c.svg',
          width: 10,
          height: 14,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              Text(
                message,
                style: careText(
                  12,
                  FontWeight.w400,
                  CareV2.muted,
                ).copyWith(height: 1.4),
              ),
              InkWell(
                onTap: action,
                child: Text(
                  'Learn more ›',
                  style: careText(12, FontWeight.w500, CareV2.teal),
                ),
              ),
            ],
          ),
        ),
      ],
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
  const _ReviewRow({
    required this.label,
    required this.value,
    this.asset,
    this.last = false,
    this.teal = false,
  });
  final String label, value;
  final String? asset;
  final bool last, teal;
  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: CareV2.outline)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: careText(12, FontWeight.w400, CareV2.muted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: careText(
              13,
              FontWeight.w500,
              teal ? CareV2.teal : CareV2.navy,
            ),
          ),
        ),
        if (asset != null) ...[
          const SizedBox(width: 5),
          SvgPicture.asset('${CareV2.assets}$asset', width: 16, height: 16),
        ],
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
