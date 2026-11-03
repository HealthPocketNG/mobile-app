import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/presentation/savings_v2_screens.dart';

enum _HistoryKind { added, plan, reversed }

enum _HistoryFilter { all, added, plan, failed }

class _HistoryEntry {
  const _HistoryEntry({
    required this.amountKobo,
    required this.date,
    required this.kind,
    required this.title,
    this.preview = false,
  });

  final int amountKobo;
  final DateTime? date;
  final _HistoryKind kind;
  final String title;
  final bool preview;
}

const _months = [
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
];

final _previewHistory = <_HistoryEntry>[
  _HistoryEntry(
    amountKobo: 50000,
    date: DateTime(2026, 9, 13, 9),
    kind: _HistoryKind.plan,
    title: 'Savings Contribution',
    preview: true,
  ),
  _HistoryEntry(
    amountKobo: 200000,
    date: DateTime(2026, 9, 10, 16, 21),
    kind: _HistoryKind.added,
    title: 'Added Money',
    preview: true,
  ),
  _HistoryEntry(
    amountKobo: 50000,
    date: DateTime(2026, 9, 6, 9),
    kind: _HistoryKind.plan,
    title: 'Savings Contribution',
    preview: true,
  ),
  _HistoryEntry(
    amountKobo: 50000,
    date: DateTime(2026, 8, 30, 9),
    kind: _HistoryKind.plan,
    title: 'Savings Contribution',
    preview: true,
  ),
  _HistoryEntry(
    amountKobo: 100000,
    date: DateTime(2026, 8, 24, 13, 14),
    kind: _HistoryKind.added,
    title: 'Added Money',
    preview: true,
  ),
  _HistoryEntry(
    amountKobo: 50000,
    date: DateTime(2026, 8, 23, 9),
    kind: _HistoryKind.plan,
    title: 'Savings Contribution',
    preview: true,
  ),
];

class SavingsHistoryV2 extends StatefulWidget {
  const SavingsHistoryV2({
    required this.store,
    this.designPreview = false,
    this.onRetry,
    super.key,
  });

  final SavingsStore store;
  final bool designPreview;
  final VoidCallback? onRetry;

  @override
  State<SavingsHistoryV2> createState() => _SavingsHistoryV2State();
}

class _SavingsHistoryV2State extends State<SavingsHistoryV2> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<_HistoryEntry> _entries() {
    final records = widget.store.contributions;
    if (widget.designPreview && records.isEmpty) return _previewHistory;
    return records
        .map(
          (record) => _HistoryEntry(
            amountKobo: record.amountKobo,
            date: record.createdAt,
            kind: record.status == ContributionStatus.reversed
                ? _HistoryKind.reversed
                : _HistoryKind.added,
            title: record.status == ContributionStatus.reversed
                ? 'Reversed contribution'
                : 'Added Money',
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });
  }

  bool _matches(_HistoryEntry entry) => switch (_filter) {
    _HistoryFilter.all => true,
    _HistoryFilter.added => entry.kind == _HistoryKind.added,
    _HistoryFilter.plan => entry.kind == _HistoryKind.plan,
    _HistoryFilter.failed => false,
  };

  Future<void> _export(List<_HistoryEntry> entries) async {
    if (widget.designPreview && widget.store.contributions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview history cannot be exported.')),
      );
      return;
    }
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There is no savings history to copy yet.'),
        ),
      );
      return;
    }
    final lines = <String>['Date,Type,Amount (NGN),Status'];
    for (final entry in entries) {
      final date = entry.date?.toIso8601String() ?? '';
      final amount = entry.amountKobo / 100;
      lines.add(
        '$date,${entry.title},$amount,${entry.kind == _HistoryKind.reversed ? 'Reversed' : 'Development record (no money moved)'}',
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Savings history copied as CSV.')),
      );
    }
  }

  void _showEntry(_HistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: savingsText(20, FontWeight.w700, SavingsV2.navy),
              ),
              const SizedBox(height: 14),
              Text(
                savingsMoney(entry.amountKobo, spaced: true),
                style: savingsText(24, FontWeight.w700, SavingsV2.teal),
              ),
              const SizedBox(height: 8),
              Text(
                _dateTime(entry.date),
                style: savingsText(13, FontWeight.w400, SavingsV2.muted),
              ),
              const SizedBox(height: 12),
              Text(
                entry.preview
                    ? 'Sample history for UI preview.'
                    : 'Development record — no money moved.',
                style: savingsText(12, FontWeight.w400, SavingsV2.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final all = _entries();
      final entries = all.where(_matches).toList();
      final loading =
          widget.store.contributionLoadStatus ==
              ContributionLoadStatus.loading &&
          all.isEmpty;
      final failed =
          widget.store.contributionLoadStatus ==
              ContributionLoadStatus.failure &&
          all.isEmpty;
      String? month;
      final historyRows = <Widget>[];
      for (final entry in entries) {
        final entryMonth = _month(entry.date);
        if (entryMonth != month) {
          if (month != null) historyRows.add(const SizedBox(height: 20));
          month = entryMonth;
          historyRows.add(
            Text(
              entryMonth,
              style: savingsText(14, FontWeight.w700, SavingsV2.navy),
            ),
          );
        }
        historyRows.add(
          _HistoryRow(entry: entry, onTap: () => _showEntry(entry)),
        );
      }
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: 28,
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SvgPicture.asset(
                            '${SavingsV2.assets}history-back.svg',
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy savings history',
                      onPressed: () => _export(all),
                      icon: SvgPicture.asset(
                        '${SavingsV2.assets}history-download.svg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Savings History',
                  style: savingsText(26, FontWeight.w700, SavingsV2.teal),
                ),
                const SizedBox(height: 4),
                Text(
                  'A record of your contributions.',
                  style: savingsText(13, FontWeight.w400, SavingsV2.muted),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _HistoryFilter.values) ...[
                        _HistoryChip(
                          label: switch (filter) {
                            _HistoryFilter.all => 'All',
                            _HistoryFilter.added => 'Added Money',
                            _HistoryFilter.plan => 'Plan Savings',
                            _HistoryFilter.failed => 'Failed',
                          },
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                        if (filter != _HistoryFilter.failed)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (failed)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Could not load savings history.',
                          style: savingsText(
                            14,
                            FontWeight.w500,
                            SavingsV2.navy,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              widget.onRetry ??
                              widget.store.retryContributionLoad,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                else if (entries.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      child: Text(
                        'No ${_filter == _HistoryFilter.all ? 'savings history' : '${_filter.name.toLowerCase()} entries'} yet.',
                        style: savingsText(
                          14,
                          FontWeight.w400,
                          SavingsV2.muted,
                        ),
                      ),
                    ),
                  )
                else
                  ...historyRows,
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
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
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? SavingsV2.teal : const Color(0xFFF0F3F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: savingsText(
          12,
          selected ? FontWeight.w600 : FontWeight.w400,
          selected ? Colors.white : SavingsV2.navy,
        ),
      ),
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.onTap});
  final _HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 67,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SavingsV2.outline)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: entry.kind == _HistoryKind.added
                ? const Color(0xFFFDE8EE)
                : SavingsV2.pale,
            child: SvgPicture.asset(
              '${SavingsV2.assets}${entry.kind == _HistoryKind.added ? 'history-added.svg' : 'history-plan.svg'}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: savingsText(14, FontWeight.w500, SavingsV2.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateTime(entry.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: savingsText(12, FontWeight.w400, SavingsV2.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${entry.kind == _HistoryKind.reversed ? '−' : '+'} ${savingsMoney(entry.amountKobo)}',
            style: savingsText(
              14,
              FontWeight.w700,
              entry.kind == _HistoryKind.reversed
                  ? const Color(0xFFE8405F)
                  : SavingsV2.teal,
            ),
          ),
        ],
      ),
    ),
  );
}

String _month(DateTime? date) => date == null
    ? 'Date unavailable'
    : '${_months[date.month - 1]} ${date.year}';

String _dateTime(DateTime? date) {
  if (date == null) return 'Date pending';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final shortMonth = date.month == 9
      ? 'Sept'
      : _months[date.month - 1].substring(0, 3);
  return '$shortMonth ${date.day}, ${date.year} • $hour:$minute $period';
}
