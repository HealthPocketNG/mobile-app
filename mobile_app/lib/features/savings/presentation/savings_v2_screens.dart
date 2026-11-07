import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/core/theme/app_ui_density.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/funding/domain/funding_transaction.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

abstract final class SavingsV2 {
  static const assets = 'assets/savings/v2/';
  static const teal = Color(0xFF0B7F7A);
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const mint = Color(0xFFEEF9F7);
  static const pale = Color(0xFFE4F6F3);
  static const outline = Color(0xFFE8EDF0);
  static const accent = Color(0xFF13A39B);
  static const previewBalanceKobo = 1250000;
}

TextStyle savingsText(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Inter',
  fontSize: AppUiDensity.font(size),
  fontWeight: weight,
  color: color,
);

String savingsMoney(int amountKobo, {bool spaced = false}) {
  final amount = amountKobo ~/ 100;
  final formatted = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₦${spaced ? ' ' : ''}$formatted';
}

class SavingsV2Button extends StatelessWidget {
  const SavingsV2Button({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.arrow = false,
    this.arrowAsset = 'cta-arrow.svg',
    this.height,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool arrow;
  final String arrowAsset;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height:
        height ??
        (secondary
            ? AppUiDensity.secondaryButtonHeight
            : AppUiDensity.primaryButtonHeight),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: secondary ? SavingsV2.pale : SavingsV2.teal,
        shape: const StadiumBorder(),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: savingsText(
                15,
                FontWeight.w600,
                secondary ? SavingsV2.teal : Colors.white,
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 10),
              SvgPicture.asset('${SavingsV2.assets}$arrowAsset'),
            ],
          ],
        ),
      ),
    ),
  );
}

class SavingsV2Header extends StatelessWidget {
  const SavingsV2Header({
    required this.title,
    required this.subtitle,
    this.backAsset = 'back-edit.svg',
    super.key,
  });

  final String title;
  final String subtitle;
  final String backAsset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 28,
        height: 36,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          icon: SvgPicture.asset('${SavingsV2.assets}$backAsset'),
        ),
      ),
      const SizedBox(height: 12),
      Text(title, style: savingsText(26, FontWeight.w700, SavingsV2.teal)),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: savingsText(
          13,
          FontWeight.w400,
          SavingsV2.muted,
        ).copyWith(height: 1.4),
      ),
    ],
  );
}

class SavingsOverviewV2 extends StatefulWidget {
  const SavingsOverviewV2({
    required this.balanceKobo,
    required this.plan,
    required this.contributions,
    required this.onEdit,
    required this.onPlanOptions,
    required this.onAddMoney,
    required this.onTogglePlan,
    required this.onHistory,
    this.designPreview = false,
    super.key,
  });

  final int balanceKobo;
  final SavingsPlan? plan;
  final List<ContributionRecord> contributions;
  final VoidCallback onEdit;
  final VoidCallback onPlanOptions;
  final VoidCallback onAddMoney;
  final VoidCallback onTogglePlan;
  final VoidCallback onHistory;
  final bool designPreview;

  @override
  State<SavingsOverviewV2> createState() => _SavingsOverviewV2State();
}

class _SavingsOverviewV2State extends State<SavingsOverviewV2> {
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final planClosed = plan?.status == SavingsPlanStatus.cancelled;
    final streak = widget.designPreview
        ? 4
        : _consecutiveWeeks(widget.contributions);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Savings',
                          style: savingsText(
                            26,
                            FontWeight.w700,
                            SavingsV2.teal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your health fund at a glance.',
                          style: savingsText(
                            13,
                            FontWeight.w400,
                            SavingsV2.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoute.notifications.path,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 32,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset('${SavingsV2.assets}bell.svg'),
                          if (widget.designPreview)
                            const Positioned(
                              top: 4,
                              right: 2,
                              child: CircleAvatar(
                                radius: 3,
                                backgroundColor: Color(0xFFE8405F),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoute.profile.path),
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFB5EDE5),
                      child: SvgPicture.asset('${SavingsV2.assets}avatar.svg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SavingsBalanceCard(
                balanceKobo: widget.balanceKobo,
                visible: _balanceVisible,
                onVisibility: () =>
                    setState(() => _balanceVisible = !_balanceVisible),
                onHistory: widget.onHistory,
              ),
              const SizedBox(height: 10),
              _SavingsInfoCard(
                asset: 'on-track.svg',
                assetSize: 24,
                title: planClosed
                    ? 'Plan closed'
                    : plan?.status == SavingsPlanStatus.paused
                    ? 'Plan paused'
                    : plan == null
                    ? 'Start your savings plan'
                    : "You're on track!",
                message: planClosed
                    ? 'Your previous savings activity is still available.'
                    : plan?.status == SavingsPlanStatus.paused
                    ? 'Resume your plan when you are ready.'
                    : plan == null
                    ? 'Choose a comfortable amount and schedule.'
                    : 'Consistent savings build healthier tomorrows.',
                iconBackground: const Color(0xFFB5EDE5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Savings Plan',
                      style: savingsText(15, FontWeight.w700, SavingsV2.navy),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onEdit,
                    child: Text(
                      plan == null ? 'Set up' : 'Edit',
                      style: savingsText(13, FontWeight.w500, SavingsV2.teal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SavingsPlanCard(
                plan: plan,
                onTap: plan == null ? widget.onEdit : widget.onPlanOptions,
                onLongPress: plan == null || planClosed
                    ? null
                    : widget.onTogglePlan,
              ),
              const SizedBox(height: 10),
              SavingsV2Button(
                label: plan == null
                    ? 'Set Your Savings Plan'
                    : planClosed
                    ? 'Plan Closed'
                    : 'Add Money',
                arrow: !planClosed,
                height: 56,
                onPressed: planClosed
                    ? null
                    : plan == null
                    ? widget.onEdit
                    : widget.onAddMoney,
              ),
              const SizedBox(height: 10),
              _SavingsInfoCard(
                asset: 'streak.svg',
                assetSize: 26,
                title: 'Streak',
                value: '$streak ${streak == 1 ? 'week' : 'weeks'}',
                message: streak == 0
                    ? 'Your savings streak starts with a contribution.'
                    : 'Keep the momentum going!',
                iconBackground: Colors.white,
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNavigation(currentIndex: 1),
      ),
    );
  }
}

class _SavingsBalanceCard extends StatelessWidget {
  const _SavingsBalanceCard({
    required this.balanceKobo,
    required this.visible,
    required this.onVisibility,
    required this.onHistory,
  });

  final int balanceKobo;
  final bool visible;
  final VoidCallback onVisibility;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Container(
    height: 146,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF0B7F7A), Color(0xFF0E9991)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Stack(
      children: [
        const Positioned(
          top: -54,
          right: -40,
          child: CircleAvatar(radius: 75, backgroundColor: Color(0x14FFFFFF)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Savings',
                    style: savingsText(14, FontWeight.w400, Colors.white),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onVisibility,
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: 28,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x2E000000),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: SvgPicture.asset(
                        '${SavingsV2.assets}visibility.svg',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                visible ? savingsMoney(balanceKobo, spaced: true) : '₦ •••••',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: savingsText(34, FontWeight.w700, Colors.white),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Keep going',
                    style: savingsText(14, FontWeight.w400, Colors.white),
                  ),
                  const SizedBox(width: 6),
                  SvgPicture.asset('${SavingsV2.assets}keep-going.svg'),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: InkWell(
            onTap: onHistory,
            borderRadius: BorderRadius.circular(20),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: SvgPicture.asset('${SavingsV2.assets}balance-arrow.svg'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SavingsInfoCard extends StatelessWidget {
  const _SavingsInfoCard({
    required this.asset,
    required this.assetSize,
    required this.title,
    required this.message,
    required this.iconBackground,
    this.value,
  });

  final String asset;
  final double assetSize;
  final String title;
  final String? value;
  final String message;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
    decoration: BoxDecoration(
      color: SavingsV2.mint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: iconBackground,
          child: SvgPicture.asset('${SavingsV2.assets}$asset'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: savingsText(
                  13,
                  value == null ? FontWeight.w700 : FontWeight.w400,
                  value == null ? SavingsV2.teal : SavingsV2.muted,
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: savingsText(18, FontWeight.w700, SavingsV2.navy),
                ),
              Text(
                message,
                style: savingsText(
                  12,
                  FontWeight.w400,
                  SavingsV2.muted,
                ).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SavingsPlanCard extends StatelessWidget {
  const _SavingsPlanCard({
    required this.plan,
    required this.onTap,
    required this.onLongPress,
  });

  final SavingsPlan? plan;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SavingsV2.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SavingsV2.pale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset('${SavingsV2.assets}plan-calendar.svg'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan == null
                        ? 'No plan yet'
                        : '${plan!.frequency.label} Savings',
                    style: savingsText(12, FontWeight.w400, SavingsV2.muted),
                  ),
                  Text(
                    plan == null
                        ? 'Set a plan'
                        : savingsMoney(plan!.contributionAmountKobo),
                    style: savingsText(18, FontWeight.w700, SavingsV2.navy),
                  ),
                  Text(
                    plan == null
                        ? 'Choose your amount and schedule'
                        : plan!.status == SavingsPlanStatus.paused
                        ? 'Plan paused'
                        : 'Next savings: ${_nextSavingsDate(plan!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: savingsText(11.5, FontWeight.w400, SavingsV2.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SavingsPlanDraft {
  const SavingsPlanDraft({
    required this.amountKobo,
    required this.frequency,
    required this.startDate,
  });
  final int amountKobo;
  final SavingsFrequency frequency;
  final DateTime startDate;
}

class SavingsPlanEditorV2 extends StatefulWidget {
  const SavingsPlanEditorV2({
    this.plan,
    this.selectStartDateImmediately = false,
    super.key,
  });
  final SavingsPlan? plan;
  final bool selectStartDateImmediately;
  @override
  State<SavingsPlanEditorV2> createState() => _SavingsPlanEditorV2State();
}

class _SavingsPlanEditorV2State extends State<SavingsPlanEditorV2> {
  late final TextEditingController _amount;
  late SavingsFrequency _frequency;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: ((widget.plan?.contributionAmountKobo ?? 50000) ~/ 100).toString(),
    );
    _frequency = widget.plan?.frequency ?? SavingsFrequency.weekly;
    _startDate = widget.plan?.startDate ?? DateTime.now();
    if (widget.selectStartDateImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectStartDate();
      });
    }
  }

  Future<void> _selectStartDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year - 1),
      lastDate: today.add(const Duration(days: 730)),
      initialDate: _startDate,
    );
    if (date != null && mounted) setState(() => _startDate = date);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_amount.text);
    if (value == null || value < 500 || value > 1000000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount from ₦500 to ₦1,000,000,000.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      SavingsPlanDraft(
        amountKobo: value * 100,
        frequency: _frequency,
        startDate: _startDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _SavingsFlowScaffold(
    button: SavingsV2Button(
      label: 'Save Plan',
      arrow: true,
      arrowAsset: 'arrow-edit.svg',
      onPressed: _save,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SavingsV2Header(
          title: 'Set Your Savings Plan',
          subtitle: 'Choose how often you want to save and set\nyour amount.',
        ),
        const SizedBox(height: 24),
        for (final frequency in SavingsFrequency.values) ...[
          _FrequencyChoice(
            frequency: frequency,
            amountKobo: (int.tryParse(_amount.text) ?? 500) * 100,
            selected: _frequency == frequency,
            onTap: () => setState(() => _frequency = frequency),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        Text(
          'Custom Amount',
          style: savingsText(15, FontWeight.w700, SavingsV2.navy),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: savingsText(20, FontWeight.w700, SavingsV2.navy),
            decoration: InputDecoration(
              prefixText: '₦ ',
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SavingsV2.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SavingsV2.outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SvgPicture.asset('${SavingsV2.assets}info.svg'),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'You can increase this amount anytime.',
                style: savingsText(12, FontWeight.w400, SavingsV2.muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FrequencyChoice extends StatelessWidget {
  const _FrequencyChoice({
    required this.frequency,
    required this.amountKobo,
    required this.selected,
    required this.onTap,
  });
  final SavingsFrequency frequency;
  final int amountKobo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (frequency) {
      SavingsFrequency.daily => 'daily.svg',
      SavingsFrequency.weekly => 'weekly.svg',
      SavingsFrequency.monthly => 'monthly.svg',
    };
    return Material(
      color: selected ? SavingsV2.mint : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? SavingsV2.accent : SavingsV2.outline,
            ),
          ),
          child: Row(
            children: [
              SvgPicture.asset('${SavingsV2.assets}$icon'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  frequency.label,
                  style: savingsText(14, FontWeight.w400, SavingsV2.navy),
                ),
              ),
              Text(
                savingsMoney(amountKobo),
                style: savingsText(14, FontWeight.w700, SavingsV2.navy),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? SavingsV2.teal : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? SavingsV2.teal : const Color(0xFF9AA3AF),
                  ),
                ),
                child: selected
                    ? const CircleAvatar(
                        radius: 4,
                        backgroundColor: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavingsAddMoneyV2 extends StatefulWidget {
  const SavingsAddMoneyV2({
    required this.canRecordDevelopmentContribution,
    this.designPreview = false,
    this.onBankPreview,
    this.onRecordConfirmed,
    super.key,
  });
  final bool canRecordDevelopmentContribution;
  final bool designPreview;
  final ValueChanged<int>? onBankPreview;
  final Future<void> Function(int amountNaira)? onRecordConfirmed;
  @override
  State<SavingsAddMoneyV2> createState() => _SavingsAddMoneyV2State();
}

class _SavingsAddMoneyV2State extends State<SavingsAddMoneyV2> {
  int _amountNaira = 1000;

  Future<void> _customAmount() async {
    final amount = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SavingsCustomAmountV2(designPreview: widget.designPreview),
      ),
    );
    if (amount != null && mounted) setState(() => _amountNaira = amount);
  }

  Future<void> _continue() async {
    if (!widget.canRecordDevelopmentContribution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank payments are not available yet.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Development contribution'),
        content: Text(
          'Record ${savingsMoney(_amountNaira * 100)} for UI testing? No money will move.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final record = widget.onRecordConfirmed;
      if (record == null) {
        Navigator.pop(context, _amountNaira);
      } else {
        await record(_amountNaira);
      }
    }
  }

  void _bank() {
    final preview = widget.onBankPreview;
    if (widget.designPreview && preview != null) {
      preview(_amountNaira);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank transfers are not available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) => _SavingsFlowScaffold(
    button: SavingsV2Button(
      label: 'Continue to Pay',
      arrow: true,
      arrowAsset: 'arrow-add.svg',
      onPressed: _continue,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SavingsV2Header(
          title: 'Add Money',
          subtitle: 'Choose or enter an amount to add to your\nHealthPocket.',
          backAsset: 'back-add.svg',
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 52,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            if (index == 5) {
              return _AmountChoice(
                label: 'Other',
                selected: !_presetAmounts.contains(_amountNaira),
                onTap: _customAmount,
              );
            }
            final amount = _presetAmounts[index];
            return _AmountChoice(
              label: savingsMoney(amount * 100),
              selected: _amountNaira == amount,
              onTap: () => setState(() => _amountNaira = amount),
            );
          },
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SavingsV2.mint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Method',
                style: savingsText(14, FontWeight.w700, SavingsV2.navy),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _bank,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SavingsV2.pale,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SvgPicture.asset('${SavingsV2.assets}bank.svg'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Pay with Bank',
                              style: savingsText(
                                13,
                                FontWeight.w700,
                                SavingsV2.navy,
                              ).copyWith(height: 1.1),
                            ),
                            Text(
                              MediaQuery.sizeOf(context).width >= 360
                                  ? 'Secure payment via your\nbank app'
                                  : 'Secure payment via your bank app',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: savingsText(
                                11.5,
                                FontWeight.w400,
                                SavingsV2.muted,
                              ).copyWith(height: 1.1),
                            ),
                          ],
                        ),
                      ),
                      SvgPicture.asset('${SavingsV2.assets}chevron.svg'),
                    ],
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

const _presetAmounts = [500, 1000, 2000, 5000, 10000];

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
  Widget build(BuildContext context) => Material(
    color: selected ? SavingsV2.mint : SavingsV2.pale,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? SavingsV2.accent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: savingsText(
            14,
            selected ? FontWeight.w700 : FontWeight.w500,
            SavingsV2.teal,
          ),
        ),
      ),
    ),
  );
}

class SavingsCustomAmountV2 extends StatefulWidget {
  const SavingsCustomAmountV2({this.designPreview = false, super.key});
  final bool designPreview;
  @override
  State<SavingsCustomAmountV2> createState() => _SavingsCustomAmountV2State();
}

class _SavingsCustomAmountV2State extends State<SavingsCustomAmountV2> {
  late String _digits;
  bool _previewUntouched = false;

  @override
  void initState() {
    super.initState();
    _digits = widget.designPreview ? '7500' : '';
    _previewUntouched = widget.designPreview;
  }

  void _press(String key) {
    setState(() {
      if (key == 'delete') {
        _previewUntouched = false;
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else if (_digits.length < 7) {
        if (_previewUntouched) {
          _digits = '';
          _previewUntouched = false;
        }
        _digits = (_digits + key).replaceFirst(RegExp(r'^0+(?=\d)'), '');
      }
    });
  }

  void _continue() {
    final amount = int.tryParse(_digits) ?? 0;
    if (!FundingAmountPolicy.isValidKobo(amount * 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount from ₦500 to ₦1,000,000.'),
        ),
      );
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        32;
    final topGap = (availableHeight - 540).clamp(16.0, 38.0);
    final buttonGap = (availableHeight - 560).clamp(20.0, 46.0);
    final keypadHeight = (availableHeight - 310).clamp(190.0, 258.0);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SavingsV2Header(
                    title: 'Enter Amount',
                    subtitle: 'How much would you like to add?',
                    backAsset: 'back-custom.svg',
                  ),
                ),
                SizedBox(height: topGap),
                Text(
                  savingsMoney(
                    (int.tryParse(_digits) ?? 0) * 100,
                    spaced: true,
                  ),
                  style: savingsText(46, FontWeight.w700, SavingsV2.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  'Minimum ₦500',
                  style: savingsText(13.5, FontWeight.w400, SavingsV2.muted),
                ),
                const Spacer(),
                SavingsV2Button(
                  label: 'Continue',
                  arrow: true,
                  arrowAsset: 'arrow-custom.svg',
                  onPressed: _continue,
                ),
                SizedBox(height: buttonGap),
                SizedBox(
                  height: keypadHeight,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 12,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: (keypadHeight - 18) / 4,
                      mainAxisSpacing: 6,
                    ),
                    itemBuilder: (context, index) {
                      final key = switch (index) {
                        9 => '',
                        10 => '0',
                        11 => 'delete',
                        _ => '${index + 1}',
                      };
                      if (key.isEmpty) return const SizedBox.shrink();
                      return InkWell(
                        key: key == 'delete'
                            ? const Key('savings-keypad-delete')
                            : null,
                        onTap: () => _press(key),
                        child: Center(
                          child: key == 'delete'
                              ? SvgPicture.asset(
                                  '${SavingsV2.assets}delete.svg',
                                )
                              : Text(
                                  key,
                                  style: savingsText(
                                    26,
                                    FontWeight.w500,
                                    SavingsV2.navy,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SavingsMoneyAddedV2 extends StatelessWidget {
  const SavingsMoneyAddedV2({
    required this.amountNaira,
    required this.newBalanceKobo,
    required this.onBack,
    required this.onActivity,
    this.developmentRecord = false,
    super.key,
  });
  final int amountNaira;
  final int newBalanceKobo;
  final VoidCallback onBack;
  final VoidCallback onActivity;
  final bool developmentRecord;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 8,
                      left: 42,
                      child: _BurstDash(Color(0xFF0B7F7A), 45),
                    ),
                    const Positioned(
                      top: 4,
                      right: 44,
                      child: _BurstDash(Color(0xFFE8405F), 30),
                    ),
                    const Positioned(
                      top: 75,
                      left: 33,
                      child: _BurstDash(Color(0xFFE8405F), 70),
                    ),
                    const Positioned(
                      top: 72,
                      right: 32,
                      child: _BurstDash(Color(0xFF13A39B), 110),
                    ),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: SavingsV2.teal,
                      child: SvgPicture.asset(
                        '${SavingsV2.assets}success-check.svg',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Text(
                'Money Added!',
                style: savingsText(22, FontWeight.w700, SavingsV2.navy),
              ),
              const SizedBox(height: 5),
              Text(
                savingsMoney(amountNaira * 100, spaced: true),
                style: savingsText(32, FontWeight.w700, SavingsV2.teal),
              ),
              const SizedBox(height: 24),
              Text(
                'has been added to your\nHealthPocket savings.',
                textAlign: TextAlign.center,
                style: savingsText(
                  13.5,
                  FontWeight.w400,
                  SavingsV2.muted,
                ).copyWith(height: 1.45),
              ),
              if (developmentRecord) ...[
                const SizedBox(height: 5),
                Text(
                  'Development record — no money moved.',
                  style: savingsText(11, FontWeight.w400, SavingsV2.muted),
                ),
              ],
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SavingsV2.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SavingsV2.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SvgPicture.asset('${SavingsV2.assets}wallet.svg'),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Balance',
                          style: savingsText(
                            12,
                            FontWeight.w400,
                            SavingsV2.muted,
                          ),
                        ),
                        Text(
                          savingsMoney(newBalanceKobo),
                          style: savingsText(
                            18,
                            FontWeight.w700,
                            SavingsV2.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SavingsV2.mint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: SvgPicture.asset(
                        '${SavingsV2.assets}success-flame.svg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You're doing great!",
                            style: savingsText(
                              13,
                              FontWeight.w700,
                              SavingsV2.navy,
                            ),
                          ),
                          Text(
                            'Every contribution brings you closer\nto a healthier tomorrow.',
                            style: savingsText(
                              12,
                              FontWeight.w400,
                              SavingsV2.muted,
                            ).copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SavingsV2Button(label: 'Back to Savings', onPressed: onBack),
              const SizedBox(height: 10),
              SavingsV2Button(
                label: 'View Activity',
                secondary: true,
                onPressed: onActivity,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BurstDash extends StatelessWidget {
  const _BurstDash(this.color, this.angle);
  final Color color;
  final double angle;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle * 3.141592653589793 / 180,
    child: Container(
      width: 5,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _SavingsFlowScaffold extends StatelessWidget {
  const _SavingsFlowScaffold({required this.child, required this.button});
  final Widget child;
  final Widget button;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: child,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: button,
        ),
      ),
    ),
  );
}

int _consecutiveWeeks(List<ContributionRecord> records) {
  final weeks = <DateTime>{};
  for (final record in records) {
    final date = record.createdAt;
    if (date == null || !record.isEligibleForDevelopmentBalance) continue;
    final day = DateTime(date.year, date.month, date.day);
    weeks.add(day.subtract(Duration(days: day.weekday - 1)));
  }
  if (weeks.isEmpty) return 0;
  final ordered = weeks.toList()..sort((a, b) => b.compareTo(a));
  var streak = 1;
  for (var index = 1; index < ordered.length; index++) {
    if (ordered[index - 1].difference(ordered[index]).inDays != 7) break;
    streak++;
  }
  return streak;
}

String _nextSavingsDate(SavingsPlan plan) {
  var next = plan.startDate;
  final now = DateTime.now();
  for (var index = 0; index < 1000 && next.isBefore(now); index++) {
    next = switch (plan.frequency) {
      SavingsFrequency.daily => next.add(const Duration(days: 1)),
      SavingsFrequency.weekly => next.add(const Duration(days: 7)),
      SavingsFrequency.monthly => DateTime(next.year, next.month + 1, next.day),
    };
  }
  final weekday = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][next.weekday - 1];
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ][next.month - 1];
  return '$weekday, $month ${next.day}, ${next.year}';
}
