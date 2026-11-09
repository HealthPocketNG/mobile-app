import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';
import 'package:healthpocket/features/care/presentation/care_v2_common.dart';
import 'package:healthpocket/features/care/presentation/care_v2_payment_states.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

enum _CarePaymentStep {
  amount,
  transfer,
  review,
  insufficient,
  pin,
  processing,
  success,
}

/// The V2 payment walkthrough is confined to fictional demo providers.
/// PIN and result screens are visual previews; no payment is submitted.
class CareV2PaymentFlow extends StatefulWidget {
  const CareV2PaymentFlow({
    required this.provider,
    this.savingsStore,
    super.key,
  });
  final CareProvider provider;
  final SavingsStore? savingsStore;

  @override
  State<CareV2PaymentFlow> createState() => _CareV2PaymentFlowState();
}

class _CareV2PaymentFlowState extends State<CareV2PaymentFlow> {
  _CarePaymentStep _step = _CarePaymentStep.amount;
  int _amountKobo = 500000;
  String? _error;
  String _demoPin = '';
  Timer? _processingTimer;

  @override
  void dispose() {
    _processingTimer?.cancel();
    super.dispose();
  }

  int get _balanceKobo => widget.savingsStore?.developmentBalanceKobo ?? 0;

  void _back() {
    if (_step == _CarePaymentStep.amount || _step == _CarePaymentStep.success) {
      Navigator.pop(context);
    } else if (_step == _CarePaymentStep.insufficient ||
        _step == _CarePaymentStep.pin) {
      setState(() => _step = _CarePaymentStep.review);
    } else if (_step == _CarePaymentStep.processing) {
      return;
    } else {
      setState(() => _step = _CarePaymentStep.values[_step.index - 1]);
    }
  }

  Future<void> _customAmount() async {
    var draft = (_amountKobo ~/ 100).toString();
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Other amount'),
        content: TextFormField(
          initialValue: draft,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₦ '),
          onChanged: (text) => draft = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(draft.replaceAll(',', ''));
              if (parsed == null || parsed < 1 || parsed > 1000000) return;
              Navigator.pop(dialogContext, parsed * 100);
            },
            child: const Text('Use amount'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _amountKobo = value;
        _error = null;
      });
    }
  }

  void _continue() {
    if (_step == _CarePaymentStep.amount) {
      if (_amountKobo <= 0 || _amountKobo > 100000000) {
        setState(() => _error = 'Enter an amount from ₦1 to ₦1,000,000.');
        return;
      }
      setState(() {
        _error = null;
        _step = _CarePaymentStep.transfer;
      });
    } else if (_step == _CarePaymentStep.transfer) {
      setState(() => _step = _CarePaymentStep.review);
    } else if (_step == _CarePaymentStep.review) {
      setState(() => _step = _CarePaymentStep.processing);
      _processingTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && _step == _CarePaymentStep.processing) {
          setState(
            () => _step = _balanceKobo < _amountKobo
                ? _CarePaymentStep.insufficient
                : _CarePaymentStep.pin,
          );
        }
      });
    }
  }

  void _enterDemoDigit(String digit) {
    if (_step != _CarePaymentStep.pin || _demoPin.length >= 4) return;
    setState(() => _demoPin += digit);
    if (_demoPin.length == 4) {
      setState(() => _step = _CarePaymentStep.processing);
      _processingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _step == _CarePaymentStep.processing) {
          setState(() {
            _demoPin = '';
            _step = _CarePaymentStep.success;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    if (step == _CarePaymentStep.pin) {
      return CareV2PinPreview(
        provider: widget.provider,
        amountKobo: _amountKobo,
        enteredDigits: _demoPin.length,
        onDigit: _enterDemoDigit,
        onDelete: () {
          if (_demoPin.isNotEmpty) {
            setState(
              () => _demoPin = _demoPin.substring(0, _demoPin.length - 1),
            );
          }
        },
        onClose: _back,
      );
    }
    if (step == _CarePaymentStep.processing) {
      return CareV2ProcessingPreview(
        provider: widget.provider,
        amountKobo: _amountKobo,
      );
    }
    if (step == _CarePaymentStep.success) {
      return CareV2SuccessPreview(
        provider: widget.provider,
        amountKobo: _amountKobo,
        onDone: _back,
      );
    }
    if (step == _CarePaymentStep.insufficient) {
      return CareV2InsufficientBalance(
        amountKobo: _amountKobo,
        balanceKobo: _balanceKobo,
        onBack: _back,
        onAddMoney: () => Navigator.pushNamed(context, '/savings/add-money'),
        onChangeAmount: () => setState(() => _step = _CarePaymentStep.amount),
      );
    }
    final arrow = switch (step) {
      _CarePaymentStep.amount => 'amount-ed152.svg',
      _CarePaymentStep.transfer => 'transfer-ed152.svg',
      _ => 'review-ed152.svg',
    };
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
                asset: step == _CarePaymentStep.amount
                    ? 'amount-16de2.svg'
                    : step == _CarePaymentStep.transfer
                    ? 'transfer-86655.svg'
                    : 'review-86655.svg',
                onTap: _back,
              ),
              const SizedBox(height: 8),
              if (step == _CarePaymentStep.amount)
                _amountBody()
              else if (step == _CarePaymentStep.transfer)
                _transferBody()
              else
                _reviewBody(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: CareV2Button(
              label: step == _CarePaymentStep.review
                  ? 'Pay ${careMoney(_amountKobo)}'
                  : 'Continue',
              arrowAsset: arrow,
              onPressed: _continue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
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
                            : setState(() => _amountKobo = row[index] * 100),
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
  );

  Widget _transferBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Bank Transfer', style: careText(26, FontWeight.w700, CareV2.teal)),
      const SizedBox(height: 3),
      Text(
        "Enter the provider's account details.",
        style: careText(13, FontWeight.w400, CareV2.muted),
      ),
      const SizedBox(height: 20),
      CareProviderSummaryV2(
        provider: widget.provider,
        badgeAsset: 'transfer-1f060.svg',
        highlighted: true,
      ),
      const SizedBox(height: 18),
      _TransferField(
        label: 'Account number',
        value: '0000000000',
        asset: 'transfer-b334d.svg',
      ),
      const SizedBox(height: 16),
      _TransferField(
        label: 'Bank name',
        value: 'Demo bank',
        asset: 'transfer-3c550.svg',
      ),
      const SizedBox(height: 16),
      _TransferField(
        label: 'Account name',
        value: '${widget.provider.name} (demo)',
        muted: true,
      ),
      const SizedBox(height: 16),
      _CareNotice(
        asset: 'transfer-348c3.svg',
        text: 'Demo details only. Do not transfer money to an account shown here.',
      ),
    ],
  );

  Widget _reviewBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Review Payment', style: careText(26, FontWeight.w700, CareV2.teal)),
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
            value: '0000000000',
            asset: 'review-399f6.svg',
          ),
          _ReviewRow(label: 'Bank name', value: 'Demo bank'),
          _ReviewRow(
            label: 'Account name',
            value: '${widget.provider.name} (demo)',
            last: true,
          ),
        ],
      ),
      const SizedBox(height: 16),
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
            onPressed: () => setState(() => _step = _CarePaymentStep.amount),
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
          const _ReviewRow(label: 'Paying from', value: 'HealthPocket Balance'),
          _ReviewRow(
            label: 'Balance',
            value: careMoney(_balanceKobo),
            last: true,
            teal: true,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _CareNotice(
        asset: 'review-7817c.svg',
        text:
            'Beta demonstration only. No payment or bank transfer will occur.',
        neutral: true,
      ),
    ],
  );
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

class _TransferField extends StatelessWidget {
  const _TransferField({
    required this.label,
    required this.value,
    this.asset,
    this.muted = false,
  });
  final String label;
  final String value;
  final String? asset;
  final bool muted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: careText(12, FontWeight.w600, CareV2.navy)),
      const SizedBox(height: 4),
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: muted ? CareV2.soft : Colors.white,
          border: muted ? null : Border.all(color: CareV2.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: careText(
                  14,
                  FontWeight.w400,
                  muted ? CareV2.muted : CareV2.navy,
                ),
              ),
            ),
            if (asset != null)
              SvgPicture.asset('${CareV2.assets}$asset', width: 20, height: 20),
          ],
        ),
      ),
    ],
  );
}

class _CareNotice extends StatelessWidget {
  const _CareNotice({
    required this.asset,
    required this.text,
    this.neutral = false,
  });
  final String asset;
  final String text;
  final bool neutral;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: neutral ? CareV2.soft : const Color(0xFFEEF9F7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          '${CareV2.assets}$asset',
          width: neutral ? 10 : 9.78,
          height: neutral ? 14 : 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: careText(
              12,
              FontWeight.w400,
              CareV2.muted,
            ).copyWith(height: 1.4),
          ),
        ),
      ],
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

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.asset,
    this.last = false,
    this.teal = false,
  });
  final String label;
  final String value;
  final String? asset;
  final bool last;
  final bool teal;

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                SvgPicture.asset(
                  '${CareV2.assets}$asset',
                  width: 16,
                  height: 16,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
