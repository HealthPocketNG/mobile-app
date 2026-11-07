import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/core/widgets/healthpocket_state_view.dart';
import 'package:healthpocket/features/activity/domain/unified_activity_ledger.dart';
import 'package:healthpocket/features/activity/presentation/activity_v2_common.dart';
import 'package:healthpocket/features/activity/presentation/activity_v2_pages.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    required this.savingsStore,
    super.key,
    this.familyStore,
    this.initialFilter = ActivityCategory.all,
    this.showBackButton = false,
    this.designPreview = false,
    this.previewEmpty = false,
  });
  final SavingsStore savingsStore;
  final FamilyPocketStore? familyStore;
  final ActivityCategory initialFilter;
  final bool showBackButton;
  final bool designPreview;
  final bool previewEmpty;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late ActivityCategory _category = widget.initialFilter;
  ActivityDateRange _dateRange = ActivityDateRange.allTime;
  ActivityDateInterval? _customRange;
  String _searchQuery = '';

  List<ActivityV2Item> _allItems() {
    if (widget.designPreview && widget.previewEmpty) {
      return const [];
    }
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
    if (ledger.isEmpty && widget.designPreview && !widget.previewEmpty) {
      return activityPreviewItems(DateTime.now());
    }
    return ledger.map(ActivityV2Item.fromLedger).toList(growable: false);
  }

  List<ActivityV2Item> _filtered(List<ActivityV2Item> items) {
    final now = DateTime.now();
    final search = _searchQuery.trim().toLowerCase();
    return items
        .where((item) {
          if (_category != ActivityCategory.all && item.category != _category) {
            return false;
          }
          if (search.isNotEmpty &&
              !'${item.title} ${item.subtitle} ${item.reference}'
                  .toLowerCase()
                  .contains(search)) {
            return false;
          }
          final date = item.createdAt;
          final start = switch (_dateRange) {
            ActivityDateRange.allTime => null,
            ActivityDateRange.last7Days => now.subtract(
              const Duration(days: 7),
            ),
            ActivityDateRange.last30Days => now.subtract(
              const Duration(days: 30),
            ),
            ActivityDateRange.custom => _customRange?.start,
          };
          if (start != null && (date == null || date.isBefore(start))) {
            return false;
          }
          if (_dateRange == ActivityDateRange.custom && _customRange != null) {
            final exclusiveEnd = DateTime(
              _customRange!.end.year,
              _customRange!.end.month,
              _customRange!.end.day + 1,
            );
            if (date == null || !date.isBefore(exclusiveEnd)) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool get _hasFilters =>
      _category != ActivityCategory.all ||
      _dateRange != ActivityDateRange.allTime ||
      _searchQuery.isNotEmpty;

  Future<void> _openFilters() async {
    final selection = await Navigator.push<ActivityV2FilterSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityV2FilterScreen(
          selection: ActivityV2FilterSelection(
            category: _category,
            range: _dateRange,
            interval: _customRange,
          ),
        ),
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _category = selection.category;
        _dateRange = selection.range;
        _customRange = selection.interval;
      });
    }
  }

  Future<void> _openSearch() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final controller = TextEditingController(text: _searchQuery);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search activity',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) => Navigator.pop(sheetContext, value),
                ),
                const SizedBox(height: 14),
                ActivityV2Button(
                  label: 'Search',
                  onTap: () => Navigator.pop(sheetContext, controller.text),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null && mounted) setState(() => _searchQuery = result);
  }

  void _clearFilters() => setState(() {
    _category = ActivityCategory.all;
    _dateRange = ActivityDateRange.allTime;
    _customRange = null;
    _searchQuery = '';
  });

  @override
  Widget build(BuildContext context) {
    final family = widget.familyStore;
    return AnimatedBuilder(
      animation: Listenable.merge([widget.savingsStore, ?family]),
      builder: (context, child) {
        final isLoading =
            widget.savingsStore.contributionLoadStatus ==
                ContributionLoadStatus.loading ||
            family?.loadStatus == FamilyPocketLoadStatus.loading;
        final hasFailure =
            widget.savingsStore.contributionLoadStatus ==
                ContributionLoadStatus.failure ||
            family?.loadStatus == FamilyPocketLoadStatus.failure;
        final allItems = _allItems();
        final items = _filtered(allItems);
        final noActivity = allItems.isEmpty && !isLoading && !hasFailure;
        final noMatch =
            allItems.isNotEmpty && items.isEmpty && !isLoading && !hasFailure;
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.1,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.showBackButton) ...[
                        ActivityV2Back(onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.showBackButton
                                  ? 'Savings History'
                                  : 'Activity',
                              style: activityText(
                                26,
                                FontWeight.w700,
                                ActivityV2.teal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.showBackButton
                                  ? 'A record of your savings contributions.'
                                  : 'Track your savings, payments and more.',
                              style: activityText(
                                13,
                                FontWeight.w400,
                                ActivityV2.muted,
                              ).copyWith(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: 'Filter activity. Long press to search.',
                        child: GestureDetector(
                          onLongPress: _openSearch,
                          child: Material(
                            color: ActivityV2.mint,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: _openFilters,
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: SvgPicture.asset(
                                    '${ActivityV2.assets}${noMatch ? 'fb363.svg' : '78b81.svg'}',
                                    width: 22,
                                    height: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!noActivity && !isLoading && !hasFailure) ...[
                    const SizedBox(height: 18),
                    if (_hasFilters)
                      _AppliedFilters(
                        category: _category,
                        range: _dateRange,
                        search: _searchQuery,
                        onClear: _clearFilters,
                        onCategoryClear: () =>
                            setState(() => _category = ActivityCategory.all),
                        onRangeClear: () => setState(() {
                          _dateRange = ActivityDateRange.allTime;
                          _customRange = null;
                        }),
                      )
                    else
                      _ActivityCategoryChips(
                        selected: _category,
                        onSelected: (category) =>
                            setState(() => _category = category),
                      ),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 80),
                    const Center(child: CircularProgressIndicator()),
                  ] else if (hasFailure) ...[
                    const SizedBox(height: 70),
                    HealthPocketStateView(
                      kind: HealthPocketStateKind.error,
                      title: 'Something went wrong',
                      message: 'We couldn’t load your activity right now. Please try again.',
                      primaryActionLabel: 'Try Again',
                      onPrimaryAction:
                          widget.savingsStore.retryContributionLoad,
                    ),
                  ] else if (noActivity) ...[
                    SizedBox(
                      height: math.max(
                        48,
                        math.min(
                          96,
                          (MediaQuery.sizeOf(context).height - 540) * .28,
                        ),
                      ),
                    ),
                    const _ActivityEmptyState(filtered: false),
                  ] else if (noMatch) ...[
                    SizedBox(
                      height: math.max(
                        52,
                        math.min(
                          104,
                          (MediaQuery.sizeOf(context).height - 540) * .3,
                        ),
                      ),
                    ),
                    const _ActivityEmptyState(filtered: true),
                  ] else ...[
                    const SizedBox(height: 20),
                    Text(
                      'Recent Activity',
                      style: activityText(14, FontWeight.w700, ActivityV2.navy),
                    ),
                    const SizedBox(height: 10),
                    for (final item in items)
                      _ActivityV2Tile(
                        item: item,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ActivityV2DetailScreen(item: item),
                          ),
                        ),
                      ),
                    if (items.any((item) => item.preview)) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Sample activity for UI preview · No payment was made.',
                        style: activityText(
                          11,
                          FontWeight.w400,
                          ActivityV2.muted,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            bottomNavigationBar: widget.showBackButton
                ? null
                : SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (noActivity)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                            child: ActivityV2Button(
                              label: 'Start Saving',
                              asset: '4695b.svg',
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoute.savings.path,
                              ),
                            ),
                          ),
                        if (noMatch)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                            child: ActivityV2Button(
                              label: 'Clear Filters',
                              secondary: true,
                              onTap: _clearFilters,
                            ),
                          ),
                        const AppBottomNavigation(
                          currentIndex: 3,
                          assetRootOverride: ActivityV2.assets,
                          iconFiles: [
                            '40668.svg',
                            '95340.svg',
                            'f073d.svg',
                            '875c2.svg',
                            'd34ee.svg',
                          ],
                          useAssetColorsOverride: true,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ActivityCategoryChips extends StatelessWidget {
  const _ActivityCategoryChips({
    required this.selected,
    required this.onSelected,
  });
  final ActivityCategory selected;
  final ValueChanged<ActivityCategory> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final category in ActivityCategory.values) ...[
          _ActivityChip(
            label: activityCategoryLabel(category),
            selected: selected == category,
            onTap: () => onSelected(category),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.closeAsset,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? closeAsset;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? ActivityV2.teal : ActivityV2.soft,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: activityText(
                12,
                selected ? FontWeight.w600 : FontWeight.w400,
                selected ? Colors.white : ActivityV2.navy,
              ),
            ),
            if (closeAsset != null) ...[
              const SizedBox(width: 8),
              SvgPicture.asset(
                '${ActivityV2.assets}$closeAsset',
                width: 12,
                height: 12,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _AppliedFilters extends StatelessWidget {
  const _AppliedFilters({
    required this.category,
    required this.range,
    required this.search,
    required this.onClear,
    required this.onCategoryClear,
    required this.onRangeClear,
  });
  final ActivityCategory category;
  final ActivityDateRange range;
  final String search;
  final VoidCallback onClear, onCategoryClear, onRangeClear;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        if (category != ActivityCategory.all) ...[
          _ActivityChip(
            label: activityCategoryLabel(category),
            selected: true,
            closeAsset: 'b3d27.svg',
            onTap: onCategoryClear,
          ),
          const SizedBox(width: 8),
        ],
        if (range != ActivityDateRange.allTime) ...[
          _ActivityChip(
            label: activityRangeLabel(range),
            selected: true,
            closeAsset: 'b3d27.svg',
            onTap: onRangeClear,
          ),
          const SizedBox(width: 8),
        ],
        if (search.isNotEmpty) ...[
          _ActivityChip(
            label: search,
            selected: true,
            closeAsset: 'b3d27.svg',
            onTap: onClear,
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _ActivityV2Tile extends StatelessWidget {
  const _ActivityV2Tile({required this.item, required this.onTap});
  final ActivityV2Item item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ActivityV2.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.isPayment ? const Color(0xFFFCE8EE) : ActivityV2.mint,
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
                    style: activityText(15, FontWeight.w700, ActivityV2.pink),
                  )
                : SvgPicture.asset(
                    '${ActivityV2.assets}${item.iconAsset}',
                    width: 24,
                    height: 24,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: activityText(14, FontWeight.w600, ActivityV2.navy),
                ),
                if (item.subtitle != item.title)
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: activityText(12, FontWeight.w400, ActivityV2.muted),
                  ),
                Text(
                  activityRelativeDate(item.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: activityText(11, FontWeight.w400, ActivityV2.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            activityMoney(item.amountKobo, signed: true),
            style: activityText(
              14,
              FontWeight.w700,
              item.amountKobo >= 0 ? ActivityV2.teal : ActivityV2.navy,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({required this.filtered});
  final bool filtered;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        '${ActivityV2.assets}${filtered ? '7a151.png' : '1efc5.png'}',
        width: 170,
        height: 170,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: 20),
      Text(
        filtered ? 'No matching activity' : 'No activity yet',
        textAlign: TextAlign.center,
        style: activityText(20, FontWeight.w700, ActivityV2.navy),
      ),
      const SizedBox(height: 8),
      Text(
        filtered ? 'Try changing or clearing your filters\nto see more.' : 'Your transactions will appear\nhere once you start saving\nor making a payment.',
        textAlign: TextAlign.center,
        style: activityText(
          13.5,
          FontWeight.w400,
          ActivityV2.muted,
        ).copyWith(height: 1.5),
      ),
    ],
  );
}
