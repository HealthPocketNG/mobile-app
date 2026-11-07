import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/activity/domain/unified_activity_ledger.dart';
import 'package:healthpocket/features/activity/presentation/activity_v2_common.dart';

class ActivityV2FilterSelection {
  const ActivityV2FilterSelection({
    required this.category,
    required this.range,
    this.interval,
  });
  final ActivityCategory category;
  final ActivityDateRange range;
  final ActivityDateInterval? interval;
}

class ActivityV2FilterScreen extends StatefulWidget {
  const ActivityV2FilterScreen({required this.selection, super.key});
  final ActivityV2FilterSelection selection;
  @override
  State<ActivityV2FilterScreen> createState() => _ActivityV2FilterScreenState();
}

class _ActivityV2FilterScreenState extends State<ActivityV2FilterScreen> {
  late ActivityCategory _category = widget.selection.category;
  late ActivityDateRange _range = widget.selection.range;
  late ActivityDateInterval? _interval = widget.selection.interval;

  Future<void> _selectRange(ActivityDateRange range) async {
    if (range != ActivityDateRange.custom) {
      setState(() => _range = range);
      return;
    }
    final interval = await Navigator.push<ActivityDateInterval>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityV2DateScreen(initial: _interval),
      ),
    );
    if (interval != null && mounted) {
      setState(() {
        _range = range;
        _interval = interval;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ActivityV2Back(onTap: () => Navigator.pop(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Filter Activity',
              style: activityText(26, FontWeight.w700, ActivityV2.teal),
            ),
            const SizedBox(height: 3),
            Text(
              'Choose what you want to see.',
              style: activityText(13, FontWeight.w400, ActivityV2.muted),
            ),
            const SizedBox(height: 26),
            Text(
              'Transaction Type',
              style: activityText(14, FontWeight.w700, ActivityV2.navy),
            ),
            const SizedBox(height: 10),
            for (final row in const [
              [
                ActivityCategory.all,
                ActivityCategory.savings,
                ActivityCategory.payments,
              ],
              [ActivityCategory.family, ActivityCategory.other],
            ]) ...[
              Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _FilterChoice(
                        label: activityCategoryLabel(row[i]),
                        selected: _category == row[i],
                        onTap: () => setState(() => _category = row[i]),
                      ),
                    ),
                  ],
                  if (row.length == 2) const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            Text(
              'Date Range',
              style: activityText(14, FontWeight.w700, ActivityV2.navy),
            ),
            const SizedBox(height: 10),
            for (final row in const [
              [ActivityDateRange.allTime, ActivityDateRange.last7Days],
              [ActivityDateRange.last30Days, ActivityDateRange.custom],
            ]) ...[
              Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _FilterChoice(
                        label: activityRangeLabel(row[i]),
                        selected: _range == row[i],
                        arrow: row[i] == ActivityDateRange.custom,
                        onTap: () => _selectRange(row[i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_range == ActivityDateRange.custom && _interval != null) ...[
              const SizedBox(height: 4),
              Text(
                '${activityDate(_interval!.start)} – ${activityDate(_interval!.end)}',
                style: activityText(12, FontWeight.w500, ActivityV2.muted),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActivityV2Button(
                label: 'Apply Filters',
                onTap: _range == ActivityDateRange.custom && _interval == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        ActivityV2FilterSelection(
                          category: _category,
                          range: _range,
                          interval: _interval,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              ActivityV2Button(
                label: 'Reset',
                secondary: true,
                onTap: () => Navigator.pop(
                  context,
                  const ActivityV2FilterSelection(
                    category: ActivityCategory.all,
                    range: ActivityDateRange.allTime,
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

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.arrow = false,
  });
  final String label;
  final bool selected, arrow;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? ActivityV2.teal : ActivityV2.soft,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 46,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: activityText(
                  12,
                  selected ? FontWeight.w600 : FontWeight.w400,
                  selected ? Colors.white : ActivityV2.navy,
                ),
              ),
            ),
            if (arrow) ...[
              const SizedBox(width: 6),
              SvgPicture.asset(
                '${ActivityV2.assets}0ebb8.svg',
                width: 14,
                height: 14,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ActivityV2DateScreen extends StatefulWidget {
  const ActivityV2DateScreen({this.initial, super.key});
  final ActivityDateInterval? initial;
  @override
  State<ActivityV2DateScreen> createState() => _ActivityV2DateScreenState();
}

class _ActivityV2DateScreenState extends State<ActivityV2DateScreen> {
  late DateTime _month;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = widget.initial?.end ?? DateTime(now.year, now.month, now.day);
    _from = widget.initial?.start ?? _to!.subtract(const Duration(days: 7));
    _month = DateTime(_to!.year, _to!.month);
  }

  void _select(DateTime day) => setState(() {
    if (_from == null || _to != null || day.isBefore(_from!)) {
      _from = day;
      _to = null;
    } else {
      _to = day;
    }
  });

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((firstWeekday + days + 6) ~/ 7) * 7;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9F9),
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ActivityV2Back(onTap: () => Navigator.pop(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Select Dates',
                style: activityText(26, FontWeight.w700, ActivityV2.teal),
              ),
              const SizedBox(height: 3),
              Text(
                'Choose a start and end date.',
                style: activityText(13, FontWeight.w400, ActivityV2.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                    icon: SvgPicture.asset(
                      '${ActivityV2.assets}d321d.svg',
                      width: 18,
                      height: 18,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthName(_month.month)} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: activityText(15, FontWeight.w700, ActivityV2.navy),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    ),
                    icon: SvgPicture.asset(
                      '${ActivityV2.assets}49e73.svg',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final weekday in const [
                    'M',
                    'T',
                    'W',
                    'T',
                    'F',
                    'S',
                    'S',
                  ])
                    Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: activityText(
                            11,
                            FontWeight.w400,
                            ActivityV2.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: 1,
                ),
                itemCount: cells,
                itemBuilder: (context, index) {
                  final number = index - firstWeekday + 1;
                  if (number < 1 || number > days) {
                    return const SizedBox.shrink();
                  }
                  final day = DateTime(_month.year, _month.month, number);
                  final selected = _sameDay(day, _from) || _sameDay(day, _to);
                  final between =
                      _from != null &&
                      _to != null &&
                      !day.isBefore(_from!) &&
                      !day.isAfter(_to!);
                  return InkWell(
                    onTap: () => _select(day),
                    child: Container(
                      decoration: BoxDecoration(
                        color: between ? ActivityV2.mint : Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? ActivityV2.teal
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$number',
                            style: activityText(
                              13,
                              selected ? FontWeight.w700 : FontWeight.w400,
                              selected ? Colors.white : ActivityV2.navy,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SelectedDate(label: 'From', value: _from),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SelectedDate(label: 'To', value: _to),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ActivityV2Button(
              label: 'Apply',
              onTap: _from == null || _to == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      ActivityDateInterval(start: _from!, end: _to!),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime date, DateTime? other) =>
    other != null &&
    date.year == other.year &&
    date.month == other.month &&
    date.day == other.day;
String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

class _SelectedDate extends StatelessWidget {
  const _SelectedDate({required this.label, required this.value});
  final String label;
  final DateTime? value;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF9F7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: activityText(11, FontWeight.w400, ActivityV2.muted)),
        Text(
          value == null ? 'Select date' : activityDate(value!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: activityText(13, FontWeight.w700, ActivityV2.navy),
        ),
      ],
    ),
  );
}

class ActivityV2DetailScreen extends StatelessWidget {
  const ActivityV2DetailScreen({required this.item, super.key});
  final ActivityV2Item item;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.reference));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reference ID copied.')));
    }
  }

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                ActivityV2Back(onTap: () => Navigator.pop(context)),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: SvgPicture.asset(
                    '${ActivityV2.assets}6e806.svg',
                    width: 22,
                    height: 22,
                  ),
                  onSelected: (value) {
                    if (value == 'copy') _copy(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy reference ID'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(child: _ActivityAvatar(item: item, size: 96)),
            const SizedBox(height: 10),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: activityText(20, FontWeight.w700, ActivityV2.navy),
            ),
            const SizedBox(height: 3),
            Text(
              item.detailLabel ?? item.subtitle,
              textAlign: TextAlign.center,
              style: activityText(12, FontWeight.w400, ActivityV2.muted),
            ),
            if (item.partner) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF9F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        '${ActivityV2.assets}9574f.svg',
                        width: 14,
                        height: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'HealthPocket Partner',
                        style: activityText(
                          11,
                          FontWeight.w400,
                          ActivityV2.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _ActivityCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activityMoney(item.amountKobo, signed: true),
                        style: activityText(
                          28,
                          FontWeight.w700,
                          ActivityV2.navy,
                        ),
                      ),
                    ),
                    ActivityV2StatusPill(completed: item.completed),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: activityText(12, FontWeight.w400, ActivityV2.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  item.createdAt == null
                      ? 'Development record'
                      : activityDate(item.createdAt!, time: true),
                  style: activityText(12, FontWeight.w400, ActivityV2.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ActivityCard(
              children: [
                ActivityV2DetailRow(
                  label: item.isPayment ? 'Paid with' : 'Funding source',
                  value: item.paymentMethod ?? 'Development record',
                ),
                ActivityV2DetailRow(
                  label: 'Reference ID',
                  value: item.reference,
                  trailing: InkWell(
                    onTap: () => _copy(context),
                    child: SvgPicture.asset(
                      '${ActivityV2.assets}161f3.svg',
                      width: 16,
                      height: 16,
                    ),
                  ),
                ),
                if (item.location != null)
                  ActivityV2DetailRow(
                    label: 'Location',
                    value: item.location!,
                    last: true,
                    trailing: SvgPicture.asset(
                      '${ActivityV2.assets}b161d.svg',
                      width: 16,
                      height: 16,
                    ),
                  )
                else
                  const SizedBox(height: 2),
              ],
            ),
            if (item.preview) ...[
              const SizedBox(height: 12),
              Text(
                'UI preview · No payment or contribution was recorded for this sample.',
                textAlign: TextAlign.center,
                style: activityText(11, FontWeight.w400, ActivityV2.muted),
              ),
            ],
            if (item.isPayment && item.preview && item.completed) ...[
              const SizedBox(height: 20),
              ActivityV2Button(
                label: 'View Receipt',
                asset: '85399.svg',
                secondary: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityV2ReceiptScreen(item: item),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({required this.item, required this.size});
  final ActivityV2Item item;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: item.isPayment
          ? const Color(0xFFFCE8EE)
          : item.category == ActivityCategory.family
          ? ActivityV2.mint
          : const Color(0xFFCFF0EC),
      shape: BoxShape.circle,
    ),
    child: item.iconAsset == null
        ? Text(
            item.title
                .split(' ')
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part[0])
                .join()
                .toUpperCase(),
            style: activityText(
              size >= 80 ? 30 : 15,
              FontWeight.w700,
              item.isPayment ? ActivityV2.pink : ActivityV2.teal,
            ),
          )
        : SvgPicture.asset(
            '${ActivityV2.assets}${item.iconAsset}',
            width: size * .5,
            height: size * .5,
          ),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: ActivityV2.outline),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class ActivityV2ReceiptScreen extends StatelessWidget {
  const ActivityV2ReceiptScreen({required this.item, super.key});
  final ActivityV2Item item;
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.1,
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(
              children: [
                ActivityV2Back(onTap: () => Navigator.pop(context)),
                const Spacer(),
                IconButton(
                  tooltip: 'Download receipt',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Receipt export is unavailable for a UI preview.',
                      ),
                    ),
                  ),
                  icon: SvgPicture.asset(
                    '${ActivityV2.assets}9ad17.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'UI preview · Not a payment receipt',
              textAlign: TextAlign.center,
              style: activityText(11, FontWeight.w500, ActivityV2.muted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: ActivityV2.outline),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F1B4C),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        '${ActivityV2.assets}930fc.svg',
                        width: 30,
                        height: 34,
                      ),
                      const SizedBox(width: 5),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Health',
                              style: activityText(
                                20,
                                FontWeight.w700,
                                ActivityV2.teal,
                              ),
                            ),
                            TextSpan(
                              text: 'Pocket',
                              style: activityText(
                                20,
                                FontWeight.w700,
                                ActivityV2.pink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'H E A L T H I E R  T O M O R R O W,  T O G E T H E R',
                    textAlign: TextAlign.center,
                    style: activityText(6, FontWeight.w500, ActivityV2.muted),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Payment Receipt',
                    style: activityText(18, FontWeight.w700, ActivityV2.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Care today. A healthier tomorrow.',
                    style: activityText(13, FontWeight.w400, ActivityV2.muted),
                  ),
                  const SizedBox(height: 18),
                  ActivityV2DetailRow(label: 'Merchant', value: item.title),
                  ActivityV2DetailRow(
                    label: 'Amount',
                    value: activityMoney(item.amountKobo),
                  ),
                  ActivityV2DetailRow(
                    label: 'Date',
                    value: item.createdAt == null
                        ? '—'
                        : activityDate(item.createdAt!, time: true),
                  ),
                  ActivityV2DetailRow(
                    label: 'Reference ID',
                    value: item.reference,
                  ),
                  ActivityV2DetailRow(
                    label: 'Payment Method',
                    value: item.paymentMethod ?? 'HealthPocket Balance',
                  ),
                  ActivityV2DetailRow(
                    label: 'Status',
                    value: item.completed
                        ? 'Completed (preview)'
                        : 'Reversed (preview)',
                    last: true,
                    trailing: SvgPicture.asset(
                      '${ActivityV2.assets}a1471.svg',
                      width: 18,
                      height: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF9F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          '${ActivityV2.assets}42bcf.svg',
                          width: 12,
                          height: 12,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Thank you for taking\na step towards a healthier you.',
                          textAlign: TextAlign.center,
                          style: activityText(
                            12,
                            FontWeight.w400,
                            ActivityV2.muted,
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
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
