import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/widgets/healthpocket_state_view.dart';
import 'package:healthpocket/features/activity/domain/unified_activity_ledger.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    required this.savingsStore,
    super.key,
    this.familyStore,
    this.initialFilter = ActivityCategory.all,
    this.showBackButton = false,
  });
  final SavingsStore savingsStore;
  final FamilyPocketStore? familyStore;
  final ActivityCategory initialFilter;
  final bool showBackButton;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late ActivityCategory _category;
  var _dateRange = ActivityDateRange.allTime;
  ActivityDateInterval? _customRange;
  @override
  void initState() {
    super.initState();
    _category = widget.initialFilter;
  }

  List<ActivityLedgerItem> _items() {
    final family = widget.familyStore;
    final pocketNames = <String, String>{
      if (family != null)
        for (final pocket in family.pockets) pocket.id: pocket.name,
    };
    final ledger = buildUnifiedActivityLedger(
      savingsRecords: widget.savingsStore.contributions,
      familyRecords: family?.contributions ?? const [],
      familyPocketNames: pocketNames,
    );
    return filterUnifiedActivityLedger(
      ledger,
      category: _category,
      dateRange: _dateRange,
      customRange: _customRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.familyStore;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.savingsStore, ?family]),
      builder: (context, child) {
        final items = _items();
        final isLoading =
            widget.savingsStore.contributionLoadStatus ==
                ContributionLoadStatus.loading ||
            family?.loadStatus == FamilyPocketLoadStatus.loading;
        final hasFailure =
            widget.savingsStore.contributionLoadStatus ==
                ContributionLoadStatus.failure ||
            family?.loadStatus == FamilyPocketLoadStatus.failure;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.arrowLeft),
                      ),
                    Expanded(
                      child: Text(
                        widget.initialFilter == ActivityCategory.savings
                            ? 'Savings History'
                            : 'Activity',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _FilterButton(onTap: () => _showFilters(context)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.initialFilter == ActivityCategory.savings
                      ? 'A record of your savings contributions.'
                      : 'Track your savings, payments and more.',
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _CategoryChips(
                  selected: _category,
                  onSelected: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (hasFailure)
                  _ActivityError(
                    onRetry: () => widget.savingsStore.retryContributionLoad(),
                  )
                else if (items.isEmpty)
                  const _EmptyActivityView()
                else
                  ...items.map(
                    (item) => _ActivityTile(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => _ActivityDetails(item: item),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFilters(BuildContext context) async {
    var category = _category;
    var range = _dateRange;
    var customRange = _customRange;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filter Activity',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Choose what you want to see.',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionLabel('Transaction Type'),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: ActivityCategory.values
                        .map(
                          (value) => _SelectionChip(
                            label: _categoryLabel(value),
                            selected: category == value,
                            onTap: () => setSheetState(() => category = value),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionLabel('Date Range'),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: ActivityDateRange.values
                        .map(
                          (value) => _SelectionChip(
                            label: _rangeLabel(value),
                            selected: range == value,
                            onTap: () async {
                              if (value == ActivityDateRange.custom) {
                                final previousRange = customRange;
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  initialDateRange: previousRange == null
                                      ? null
                                      : DateTimeRange(
                                          start: previousRange.start,
                                          end: previousRange.end,
                                        ),
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    range = value;
                                    customRange = ActivityDateInterval(
                                      start: picked.start,
                                      end: picked.end,
                                    );
                                  });
                                }
                              } else {
                                setSheetState(() => range = value);
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                  if (range == ActivityDateRange.custom && customRange == null)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Choose a custom date range to apply it.',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: 'Apply Filters',
                    onPressed:
                        range == ActivityDateRange.custom && customRange == null
                        ? null
                        : () {
                            setState(() {
                              _category = category;
                              _dateRange = range;
                              _customRange = customRange;
                            });
                            Navigator.pop(context);
                          },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _category = ActivityCategory.all;
                        _dateRange = ActivityDateRange.allTime;
                        _customRange = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Center(child: Text('Reset')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});
  final ActivityCategory selected;
  final ValueChanged<ActivityCategory> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: ActivityCategory.values
          .map(
            (value) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _SelectionChip(
                label: _categoryLabel(value),
                selected: selected == value,
                onTap: () => onSelected(value),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceMuted,
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onTap,
      icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
    ),
  );
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.surfaceMuted,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.onTap});
  final ActivityLedgerItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final family = item.category == ActivityCategory.family;
    final failed = item.record.status == ContributionStatus.reversed;
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: family
                    ? const Color(0xFFFFEEF1)
                    : AppColors.primarySoft,
                child: Icon(
                  family ? LucideIcons.usersRound : LucideIcons.piggyBank,
                  color: family ? AppColors.secondary : AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${item.subtitle} · ${_dateLabel(item.record.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (item.isIncoming ? '+' : '-') +
                        _formatKobo(item.record.amountKobo),
                    style: TextStyle(
                      color: failed
                          ? AppColors.error
                          : item.isIncoming
                          ? AppColors.primary
                          : AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (failed)
                    const Text(
                      'Reversed',
                      style: TextStyle(color: AppColors.error, fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityDetails extends StatelessWidget {
  const _ActivityDetails({required this.item});
  final ActivityLedgerItem item;
  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final isFamily = item.category == ActivityCategory.family;
    final completed = record.status == ContributionStatus.recorded;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.arrowLeft),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Transaction Details',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isFamily
                        ? const Color(0xFFFFEEF1)
                        : AppColors.primarySoft,
                    child: Icon(
                      isFamily ? LucideIcons.usersRound : LucideIcons.piggyBank,
                      color: isFamily ? AppColors.secondary : AppColors.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    (record.amountKobo >= 0 ? '+' : '-') +
                        _formatKobo(record.amountKobo),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatusPill(completed: completed),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailRow(label: 'Date', value: _fullDate(record.createdAt)),
            _DetailRow(label: 'Type', value: item.title),
            _DetailRow(
              label: isFamily ? 'Family Pocket' : 'Pocket',
              value: item.subtitle,
            ),
            if (record.contributorName != null)
              _DetailRow(label: 'Contributor', value: record.contributorName!),
            _DetailRow(
              label: 'Funding source',
              value: record.moneyMovement
                  ? 'HealthPocket Balance'
                  : 'Development record',
            ),
            _DetailRow(label: 'Reference ID', value: record.id, copyable: true),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.completed});
  final bool completed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: completed ? AppColors.primarySoft : AppColors.secondarySoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      completed ? 'Completed' : 'Reversed',
      style: TextStyle(
        color: completed ? AppColors.primaryDark : AppColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });
  final String label, value;
  final bool copyable;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(color: AppColors.inkMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (copyable)
          IconButton(
            tooltip: 'Copy reference ID',
            icon: const Icon(LucideIcons.copy, size: 17),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reference ID copied.')),
              );
            },
          ),
      ],
    ),
  );
}

class _ActivityError extends StatelessWidget {
  const _ActivityError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => HealthPocketStateView(
    kind: HealthPocketStateKind.error,
    title: 'Something went wrong',
    message: 'We couldn’t load your activity right now. Please try again.',
    primaryActionLabel: 'Try Again',
    onPrimaryAction: onRetry,
  );
}

class _EmptyActivityView extends StatelessWidget {
  const _EmptyActivityView();
  @override
  Widget build(BuildContext context) => HealthPocketStateView(
    kind: HealthPocketStateKind.empty,
    title: 'No activity yet',
    message: 'Your transactions will appear here once you start saving or making payments.',
    primaryActionLabel: 'Start Saving  →',
    onPrimaryAction: () => Navigator.pushNamed(context, AppRoute.savings.path),
  );
}

String _categoryLabel(ActivityCategory category) => switch (category) {
  ActivityCategory.all => 'All',
  ActivityCategory.savings => 'Savings',
  ActivityCategory.payments => 'Payments',
  ActivityCategory.family => 'Family',
  ActivityCategory.other => 'Other',
};
String _rangeLabel(ActivityDateRange range) => switch (range) {
  ActivityDateRange.allTime => 'All Time',
  ActivityDateRange.last7Days => 'Last 7 Days',
  ActivityDateRange.last30Days => 'Last 30 Days',
  ActivityDateRange.custom => 'Custom Range',
};
String _formatKobo(int value) {
  final naira = value.abs() ~/ 100;
  return '₦${naira.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
}

String _dateLabel(DateTime? date) {
  if (date == null) return 'Development record';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '$days days ago';
}

String _fullDate(DateTime? date) {
  if (date == null) return 'Development record';
  return '${_month(date.month)} ${date.day}, ${date.year}';
}

String _month(int month) => const [
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
