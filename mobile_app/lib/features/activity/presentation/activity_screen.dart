import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum _ActivityFilter { all, savings, payments, family, other }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({required this.savingsStore, super.key});

  final SavingsStore savingsStore;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  var _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.savingsStore,
    builder: (context, child) {
      final contributions = _filter == _ActivityFilter.all ||
              _filter == _ActivityFilter.savings
          ? widget.savingsStore.contributions
          : const [];
      return Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList.list(children: [
                  Row(children: [
                    Text(
                      'Activity',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const Spacer(),
                    _FilterButton(onTap: () => _showFilters(context)),
                  ]),
                  const SizedBox(height: 2),
                  const Text(
                    'Track your savings, payments and more.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _ActivityFilter.values
                          .map(
                            (filter) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterPill(
                                label: _labelFor(filter),
                                selected: _filter == filter,
                                onTap: () => setState(() => _filter = filter),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.savingsStore.contributionLoadStatus ==
                      ContributionLoadStatus.loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (contributions.isEmpty)
                    const _EmptyActivityView()
                  else
                    ...contributions.map(
                      (contribution) => _ActivityRecordTile(
                        amountKobo: contribution.amountKobo,
                        createdAt: contribution.createdAt,
                      ),
                    ),
                ]),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _showFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .76,
      minChildSize: .45,
      maxChildSize: .92,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(
              'Filter Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose what you want to see.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 24),
            const _FilterSectionTitle('Transaction Type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _ActivityFilter.values
                  .map(
                    (filter) => SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 50) / 2,
                      child: _SheetFilterChoice(
                        label: _labelFor(filter),
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            const _FilterSectionTitle('Date Range'),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StaticSheetChoice(label: 'All Time', selected: true),
                _StaticSheetChoice(label: 'Last 7 Days'),
                _StaticSheetChoice(label: 'Last 30 Days'),
                _StaticSheetChoice(label: 'Custom Range'),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filters'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _filter = _ActivityFilter.all),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
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
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(LucideIcons.slidersHorizontal, size: 20),
      ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary : AppColors.surfaceMuted,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
  );
}

class _SheetFilterChoice extends StatelessWidget {
  const _SheetFilterChoice({required this.label, required this.selected, required this.onTap});
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
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _StaticSheetChoice extends StatelessWidget {
  const _StaticSheetChoice({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 50) / 2,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: selected ? Colors.white : AppColors.ink),
      ),
    ),
  );
}

class _EmptyActivityView extends StatelessWidget {
  const _EmptyActivityView();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
    child: Column(children: [
      Image.asset('assets/activity/no-activity.png', height: 165),
      const SizedBox(height: 12),
      Text('No activity yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Your transactions will appear here once you start saving or making payments.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkMuted)),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.pushNamed(context, AppRoute.savings.path),
          icon: const Icon(LucideIcons.arrowRight),
          iconAlignment: IconAlignment.end,
          label: const Text('Start Saving'),
        ),
      ),
    ]),
  );
}

class _ActivityRecordTile extends StatelessWidget {
  const _ActivityRecordTile({required this.amountKobo, required this.createdAt});
  final int amountKobo;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.outline)),
    ),
    child: Row(children: [
      const CircleAvatar(radius: 21, backgroundColor: AppColors.primarySoft, child: Icon(LucideIcons.piggyBank, color: AppColors.primary, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Savings Contribution', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(_dateLabel(createdAt), style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ])),
      Text('+${_formatKobo(amountKobo)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
    ]),
  );
}

String _labelFor(_ActivityFilter filter) => switch (filter) {
  _ActivityFilter.all => 'All',
  _ActivityFilter.savings => 'Savings',
  _ActivityFilter.payments => 'Payments',
  _ActivityFilter.family => 'Family',
  _ActivityFilter.other => 'Other',
};

String _formatKobo(int amountKobo) {
  final naira = amountKobo ~/ 100;
  final value = naira.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  return '₦$value';
}

String _dateLabel(DateTime? date) {
  if (date == null) return 'Development record • No money moved';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'Today • No money moved';
  if (days == 1) return 'Yesterday • No money moved';
  return '$days days ago • No money moved';
}
