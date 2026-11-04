import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';
import 'package:healthpocket/features/savings/presentation/savings_v2_screens.dart';

/// UI preview for the bank-transfer journey. A provider-issued account and
/// transfer-status API must replace this data before live funding is enabled.
class SavingsTransferDetailsV2 extends StatefulWidget {
  const SavingsTransferDetailsV2({required this.amountNaira, super.key});

  final int amountNaira;

  @override
  State<SavingsTransferDetailsV2> createState() =>
      _SavingsTransferDetailsV2State();
}

class _SavingsTransferDetailsV2State extends State<SavingsTransferDetailsV2>
    with WidgetsBindingObserver {
  static const _initialSeconds = 29 * 60 + 42;
  int _remainingSeconds = _initialSeconds;
  Timer? _countdown;
  late final DateTime _expiresAt;

  @override
  void initState() {
    super.initState();
    _expiresAt = DateTime.now().add(const Duration(seconds: _initialSeconds));
    WidgetsBinding.instance.addObserver(this);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final remaining = _expiresAt.difference(DateTime.now()).inSeconds;
    setState(() => _remainingSeconds = remaining.clamp(0, _initialSeconds));
    if (_remainingSeconds == 0) _countdown?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    super.dispose();
  }

  String get _timeLeft {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _receiving(BuildContext context) =>
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SavingsReceivingV2(amountNaira: widget.amountNaira),
        ),
      );

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          children: [
            SavingsV2Header(
              title: 'Transfer to Add Money',
              subtitle:
                  'Send exactly ${savingsMoney(widget.amountNaira * 100)} from your bank app to the account below.',
              backAsset: 'transfer-back.svg',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: SavingsV2.mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _TransferDetailRow(label: 'Bank', value: 'Demo Bank'),
                  _TransferDetailRow(
                    label: 'Account number',
                    value: '0000000000',
                    trailing: InkWell(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Preview account only. No bank transfer details to copy.',
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            '${SavingsV2.assets}transfer-copy.svg',
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: savingsText(
                              12,
                              FontWeight.w500,
                              SavingsV2.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _TransferDetailRow(
                    label: 'Account name',
                    value: 'UI Preview',
                  ),
                  _TransferDetailRow(
                    label: 'Amount',
                    value: savingsMoney(widget.amountNaira * 100),
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBC8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('${SavingsV2.assets}transfer-clock.svg'),
                    const SizedBox(width: 6),
                    Text(
                      _remainingSeconds == 0
                          ? 'Preview expired'
                          : 'Expires in $_timeLeft',
                      style: savingsText(
                        12,
                        FontWeight.w500,
                        const Color(0xFF9A6200),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: SavingsV2.mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: SvgPicture.asset(
                      '${SavingsV2.assets}transfer-info.svg',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'UI preview only. Do not send money; no bank account has been assigned.',
                      style: savingsText(
                        11.5,
                        FontWeight.w400,
                        SavingsV2.muted,
                      ).copyWith(height: 1.5),
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SavingsV2Button(
                label: "I've sent the money",
                onPressed: _remainingSeconds == 0
                    ? null
                    : () => _receiving(context),
              ),
              const SizedBox(height: 12),
              SavingsV2Button(
                label: 'Cancel',
                secondary: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TransferDetailRow extends StatelessWidget {
  const _TransferDetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.last = false,
  });
  final String label;
  final String value;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    height: 43,
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: SavingsV2.outline)),
    ),
    child: Row(
      children: [
        Text(label, style: savingsText(11.5, FontWeight.w400, SavingsV2.muted)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: savingsText(13, FontWeight.w500, SavingsV2.navy),
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: MediaQuery.sizeOf(context).width < 360 ? 4 : 12),
          Tooltip(message: 'Copy unavailable in UI preview', child: trailing!),
        ],
      ],
    ),
  );
}

class SavingsReceivingV2 extends StatefulWidget {
  const SavingsReceivingV2({required this.amountNaira, super.key});
  final int amountNaira;
  @override
  State<SavingsReceivingV2> createState() => _SavingsReceivingV2State();
}

class _SavingsReceivingV2State extends State<SavingsReceivingV2>
    with SingleTickerProviderStateMixin {
  Timer? _previewTimer;
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _previewTimer = Timer(const Duration(seconds: 10), _notReceived);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.stop();
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _rotation.dispose();
    super.dispose();
  }

  void _notReceived() {
    if (!mounted) return;
    _previewTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SavingsNotReceivedV2(amountNaira: widget.amountNaira),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final top = constraints.maxHeight >= 760
                ? 214.0
                : (constraints.maxHeight * .16).clamp(60.0, 130.0);
            return Column(
              children: [
                SizedBox(height: top),
                GestureDetector(
                  onTap: _notReceived,
                  child: Semantics(
                    label: 'Preview next transfer state',
                    child: RotationTransition(
                      key: const Key('receiving-spinner'),
                      turns: _rotation,
                      child: SvgPicture.asset(
                        '${SavingsV2.assets}receiving-spinner.svg',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirming your transfer',
                  style: savingsText(20, FontWeight.w700, SavingsV2.navy),
                ),
                const SizedBox(height: 8),
                Text(
                  'This usually takes less than a minute.\nWe’ll add the money to your balance once it arrives.',
                  textAlign: TextAlign.center,
                  style: savingsText(
                    13.5,
                    FontWeight.w400,
                    SavingsV2.muted,
                  ).copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: SavingsV2.mint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: SvgPicture.asset(
                            '${SavingsV2.assets}receiving-wallet.svg',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Money',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: savingsText(
                                  15,
                                  FontWeight.w700,
                                  SavingsV2.navy,
                                ),
                              ),
                              Text(
                                'Bank transfer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: savingsText(
                                  12,
                                  FontWeight.w400,
                                  SavingsV2.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          savingsMoney(widget.amountNaira * 100),
                          style: savingsText(
                            16,
                            FontWeight.w700,
                            SavingsV2.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'UI preview — no transfer is being checked.',
                  style: savingsText(11, FontWeight.w400, SavingsV2.muted),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoute.dashboard.path,
                    (_) => false,
                  ),
                  child: Text(
                    'Back to Home',
                    style: savingsText(15, FontWeight.w600, SavingsV2.teal),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class SavingsNotReceivedV2 extends StatelessWidget {
  const SavingsNotReceivedV2({required this.amountNaira, super.key});
  final int amountNaira;

  void _checkAgain(BuildContext context) => Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SavingsReceivingV2(amountNaira: amountNaira),
    ),
  );

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              SizedBox(
                height: (constraints.maxHeight * .138).clamp(40.0, 118.0),
              ),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 180,
                  child: Center(
                    child: Image.asset(
                      '${SavingsV2.assets}not-received.png',
                      width: 188,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "We haven't received your transfer",
                textAlign: TextAlign.center,
                style: savingsText(20, FontWeight.w700, SavingsV2.navy),
              ),
              const SizedBox(height: 8),
              Text(
                "We haven't received ${savingsMoney(amountNaira * 100)} yet. If you've already sent it, it can take a few minutes to arrive.",
                textAlign: TextAlign.center,
                style: savingsText(
                  13.5,
                  FontWeight.w400,
                  SavingsV2.muted,
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Start over',
                    style: savingsText(13, FontWeight.w500, SavingsV2.teal),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'UI preview — no transfer is being tracked.',
                textAlign: TextAlign.center,
                style: savingsText(11, FontWeight.w400, SavingsV2.muted),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SavingsV2Button(
                label: 'Check Again',
                onPressed: () => _checkAgain(context),
              ),
              const SizedBox(height: 12),
              SavingsV2Button(
                label: 'Contact Support',
                secondary: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
