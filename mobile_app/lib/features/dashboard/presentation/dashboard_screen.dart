import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/dashboard/data/mock_dashboard_data.dart';
import 'package:healthpocket/features/dashboard/domain/coverage_guide.dart';
import 'package:healthpocket/features/dashboard/presentation/coverage_details_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

abstract final class _DashboardV2 {
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const teal = Color(0xFF0B7F7A);
  static const paleTeal = Color(0xFFE4F6F3);
  static const palePink = Color(0xFFFDE8EE);
  static const divider = Color(0xFFE8EDF0);
  static const assets = 'assets/dashboard/v2/';
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.savingsStore,
    required this.profileStore,
    super.key,
    this.developmentContributionsEnabled = false,
    this.onRetryContributions,
    this.onRefresh,
  });

  final SavingsStore savingsStore;
  final ProfileStore profileStore;
  final bool developmentContributionsEnabled;
  final VoidCallback? onRetryContributions;
  final Future<void> Function()? onRefresh;

  Future<void> _refresh(BuildContext context) async {
    try {
      await onRefresh?.call();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updates could not be refreshed. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([savingsStore, profileStore]),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter'),
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                  sliver: SliverList.list(
                    children: [
                      _DashboardHeader(profileStore: profileStore),
                      const SizedBox(height: 14),
                      _SavingsBalanceCard(
                        store: savingsStore,
                        developmentContributionsEnabled:
                            developmentContributionsEnabled,
                      ),
                      const SizedBox(height: 14),
                      _CoveragePanel(
                        balanceKobo: savingsStore.developmentBalanceKobo,
                      ),
                      const SizedBox(height: 14),
                      _PrimaryActions(
                        onAddMoney: () =>
                            Navigator.pushNamed(context, AppRoute.savings.path),
                        onFamilyPocket: () => Navigator.pushNamed(
                          context,
                          AppRoute.familyPocket.path,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _RecentActivity(
                        store: savingsStore,
                        developmentContributionsEnabled:
                            developmentContributionsEnabled,
                        onRetry: onRetryContributions,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
      ),
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profileStore});
  final ProfileStore profileStore;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Greetings ${_firstName(profileStore.profile.fullName)},',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _DashboardV2.muted,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 220;
                  return SizedBox(
                    height: narrow ? 72 : 53,
                    child: Stack(
                      children: [
                        Text(
                          'There’s a healthier\ntomorrow ahead.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: _DashboardV2.navy,
                            fontSize: narrow ? 18 : 21,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        Positioned(
                          left: narrow ? null : 180,
                          right: narrow ? 0 : null,
                          bottom: 0,
                          child: SvgPicture.asset(
                            '${_DashboardV2.assets}sprout.svg',
                            width: 22,
                            height: 22,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have no new notifications.')),
          ),
          icon: Badge(
            smallSize: 9,
            backgroundColor: const Color(0xFFE8405F),
            child: SvgPicture.asset(
              '${_DashboardV2.assets}bell.svg',
              width: 28,
              height: 28,
            ),
          ),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 6),
        Semantics(
          label: '${_firstName(profileStore.profile.fullName)} profile',
          child: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFB5EDE5),
            child: SvgPicture.asset(
              '${_DashboardV2.assets}avatar.svg',
              width: 28,
              height: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavingsBalanceCard extends StatefulWidget {
  const _SavingsBalanceCard({
    required this.store,
    required this.developmentContributionsEnabled,
  });
  final SavingsStore store;
  final bool developmentContributionsEnabled;

  @override
  State<_SavingsBalanceCard> createState() => _SavingsBalanceCardState();
}

class _SavingsBalanceCardState extends State<_SavingsBalanceCard> {
  var _isBalanceHidden = false;

  @override
  Widget build(BuildContext context) {
    final balanceKobo = widget.store.developmentBalanceKobo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, AppRoute.savings.path),
        child: Ink(
          height: 142 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 250,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A7F7B), Color(0xFF0E9A93)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -58,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x14FFFFFF),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          'Total Savings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tooltip(
                        message: _isBalanceHidden
                            ? 'Show savings balance'
                            : 'Hide savings balance',
                        child: Semantics(
                          button: true,
                          label: _isBalanceHidden
                              ? 'Show savings balance'
                              : 'Hide savings balance',
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _isBalanceHidden = !_isBalanceHidden,
                            ),
                            child: Container(
                              width: 28,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0x2E000000),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(
                                child: _isBalanceHidden
                                    ? const Icon(
                                        LucideIcons.eyeOff,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : SvgPicture.asset(
                                        '${_DashboardV2.assets}balance-visibility.svg',
                                        width: 16,
                                        height: 16,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    _isBalanceHidden ? '₦••••••' : _formatKobo(balanceKobo),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontFamily: 'Inter',
                      fontSize: 34,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.developmentContributionsEnabled &&
                                      balanceKobo > 0
                                  ? 'Keep going'
                                  : 'Start your health fund',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            '${_DashboardV2.assets}keep-going.svg',
                            width: 20,
                            height: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: -2,
                bottom: 4,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: SvgPicture.asset(
                    '${_DashboardV2.assets}savings-arrow.svg',
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.balanceKobo});
  final int balanceKobo;

  @override
  Widget build(BuildContext context) {
    final eligibleGuides = eligibleDashboardCoverageForBalance(balanceKobo);
    final message = balanceKobo <= 0
        ? 'Start saving to see the care your balance can cover.'
        : 'You’re close! Continue saving to see the care your balance can cover.';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF9F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'What can my balance cover?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'Inter',
                    color: _DashboardV2.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CoverageDetailsScreen(balanceKobo: balanceKobo),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                label: const Text(
                  'See more',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: _DashboardV2.teal,
                  ),
                ),
                icon: SvgPicture.asset(
                  '${_DashboardV2.assets}see-more.svg',
                  width: 14,
                  height: 14,
                ),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (eligibleGuides.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
              child: Text(
                message,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 300
                  ? Row(
                      children: [
                        for (
                          var index = 0;
                          index < eligibleGuides.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(width: 6),
                          Expanded(
                            child: _CoverageTile(guide: eligibleGuides[index]),
                          ),
                        ],
                      ],
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final guide in eligibleGuides) ...[
                            SizedBox(
                              width: 106,
                              child: _CoverageTile(guide: guide),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.guide});
  final CoverageGuide guide;
  @override
  Widget build(BuildContext context) => Container(
    height: 75 + (MediaQuery.textScalerOf(context).scale(1) - 1) * 60,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        SvgPicture.asset(
          switch (guide.title) {
            'Malaria treatment' => '${_DashboardV2.assets}coverage-malaria.svg',
            'Basic tests' => '${_DashboardV2.assets}coverage-basic-tests.svg',
            'First aid essentials' =>
              '${_DashboardV2.assets}coverage-first-aid.svg',
            _ => guide.asset,
          },
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                guide.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _DashboardV2.muted,
                  fontSize: 11,
                  height: 1.15,
                ),
              ),
              if (guide.title == 'Basic tests')
                const Text(
                  '(e.g. blood test)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _DashboardV2.muted,
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                _formatNaira(guide.referenceCost),
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _DashboardV2.teal,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onAddMoney,
    required this.onFamilyPocket,
  });
  final VoidCallback onAddMoney;
  final VoidCallback onFamilyPocket;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ActionButton(
          label: 'Add Money',
          asset: 'action-add-money.svg',
          color: _DashboardV2.paleTeal,
          onTap: onAddMoney,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionButton(
          label: 'Find Care',
          asset: 'action-find-care.svg',
          color: _DashboardV2.palePink,
          onTap: () => Navigator.pushNamed(context, AppRoute.findCare.path),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ActionButton(
          label: 'Family Pocket',
          asset: 'action-family.svg',
          color: _DashboardV2.paleTeal,
          onTap: onFamilyPocket,
        ),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.asset,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String asset;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Ink(
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.asset(
                '${_DashboardV2.assets}$asset',
                width: label == 'Family Pocket' ? 28 : 26,
                height: label == 'Family Pocket' ? 28 : 26,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: _DashboardV2.navy,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.store,
    required this.developmentContributionsEnabled,
    this.onRetry,
  });
  final SavingsStore store;
  final bool developmentContributionsEnabled;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Inter',
                fontSize: 16,
                color: _DashboardV2.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoute.activity.path),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'See all',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: _DashboardV2.muted,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      if (store.contributionLoadStatus == ContributionLoadStatus.loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        )
      else if (store.contributionLoadStatus == ContributionLoadStatus.failure)
        _ActivityFailure(onRetry: onRetry)
      else if (!developmentContributionsEnabled || store.contributions.isEmpty)
        const _EmptyActivity()
      else
        ...store.contributions
            .take(3)
            .toList()
            .asMap()
            .entries
            .map(
              (entry) => _ActivityTile(
                amountKobo: entry.value.amountKobo,
                date: entry.value.createdAt,
                showDivider: entry.key > 0,
              ),
            ),
    ],
  );
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Image.asset(
          'assets/activity/no-activity.png',
          height: 104,
          fit: BoxFit.contain,
        ),
        const Text(
          'No activity yet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        const Text(
          'Your savings activity will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
      ],
    ),
  );
}

class _ActivityFailure extends StatelessWidget {
  const _ActivityFailure({this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'We could not load your activity.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.amountKobo,
    required this.date,
    required this.showDivider,
  });
  final int amountKobo;
  final DateTime? date;
  final bool showDivider;
  @override
  Widget build(BuildContext context) => Container(
    height: 61 * MediaQuery.textScalerOf(context).scale(1),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
    decoration: BoxDecoration(
      border: showDivider
          ? const Border(top: BorderSide(color: _DashboardV2.divider))
          : null,
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _DashboardV2.paleTeal,
          child: SvgPicture.asset(
            '${_DashboardV2.assets}activity-family.svg',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Savings Contribution',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: _DashboardV2.navy,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _activityDate(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _DashboardV2.muted,
                ),
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '+${_formatKobo(amountKobo)}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _DashboardV2.teal,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

String _firstName(String fullName) {
  final value = fullName.trim();
  if (value.isEmpty) return MockDashboardData.firstName;
  return value.split(RegExp(r'\s+')).first;
}

String _formatNaira(int amount) =>
    '₦${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
String _formatKobo(int amountKobo) {
  final naira = amountKobo ~/ 100;
  final kobo = amountKobo.remainder(100).abs();
  return kobo == 0
      ? _formatNaira(naira)
      : '${_formatNaira(naira)}.${kobo.toString().padLeft(2, '0')}';
}

String _activityDate(DateTime? date) {
  if (date == null) return 'Development record • Saving… • No money moved';
  final difference = DateTime.now().difference(date).inDays;
  if (difference <= 0) return 'Development record • Today • No money moved';
  if (difference == 1) return 'Development record • Yesterday • No money moved';
  return 'Development record • $difference days ago • No money moved';
}
