import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/dashboard/domain/coverage_guide.dart';
import 'package:healthpocket/features/dashboard/presentation/coverage_details_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

abstract final class _DashboardV2 {
  static const navy = Color(0xFF0F1B4C);
  static const muted = Color(0xFF5B6477);
  static const teal = Color(0xFF0B7F7A);
  static const paleTeal = Color(0xFFE4F6F3);
  static const palePink = Color(0xFFFDE8EE);
  static const divider = Color(0xFFE8EDF0);
  static const assets = 'assets/dashboard/v2/';
  static const sampleBalanceKobo = 1250000;
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.savingsStore,
    required this.profileStore,
    super.key,
    this.developmentContributionsEnabled = false,
    this.designPreview = false,
    this.onRetryContributions,
    this.onRefresh,
  });

  final SavingsStore savingsStore;
  final ProfileStore profileStore;
  final bool developmentContributionsEnabled;
  final bool designPreview;
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
    builder: (context, _) {
      final balanceKobo = designPreview
          ? _DashboardV2.sampleBalanceKobo
          : savingsStore.developmentBalanceKobo;
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    sliver: SliverList.list(
                      children: [
                        _DashboardHeader(profileStore: profileStore),
                        const SizedBox(height: 14),
                        _SavingsBalanceCard(
                          balanceKobo: balanceKobo,
                          designPreview: designPreview,
                        ),
                        const SizedBox(height: 14),
                        _CoveragePanel(balanceKobo: balanceKobo),
                        const SizedBox(height: 14),
                        const _PrimaryActions(),
                        const SizedBox(height: 14),
                        _RecentActivity(
                          store: savingsStore,
                          designPreview: designPreview,
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
      );
    },
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profileStore});
  final ProfileStore profileStore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 330;
      final headline = TextStyle(
        fontFamily: 'Inter',
        color: _DashboardV2.navy,
        fontSize: compact ? 18 : 21,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );
      final name = _firstName(profileStore.profile.fullName);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Greetings $name,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _DashboardV2.muted,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('There’s a healthier', style: headline),
                ),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('tomorrow ahead.', style: headline),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SvgPicture.asset(
                      '${_DashboardV2.assets}sprout.svg',
                      width: 22,
                      height: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 22),
          Row(
            children: [
              IconButton(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 48),
                padding: EdgeInsets.zero,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You have no new notifications.'),
                  ),
                ),
                tooltip: 'Notifications',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SvgPicture.asset(
                      '${_DashboardV2.assets}bell.svg',
                      width: 28,
                      height: 28,
                    ),
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8405F),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 10 : 14),
              InkWell(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoute.profile.path),
                customBorder: const CircleBorder(),
                child: Semantics(
                  button: true,
                  label: '$name profile',
                  child: CircleAvatar(
                    radius: compact ? 24 : 28,
                    backgroundColor: const Color(0xFFB5EDE5),
                    child: SvgPicture.asset(
                      '${_DashboardV2.assets}avatar.svg',
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _SavingsBalanceCard extends StatefulWidget {
  const _SavingsBalanceCard({
    required this.balanceKobo,
    required this.designPreview,
  });
  final int balanceKobo;
  final bool designPreview;

  @override
  State<_SavingsBalanceCard> createState() => _SavingsBalanceCardState();
}

class _SavingsBalanceCardState extends State<_SavingsBalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.pushNamed(context, AppRoute.savings.path),
      child: Ink(
        height: 142,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A7F7B), Color(0xFF0E9A93)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 62, 12),
              child: Column(
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
                        message: _hidden
                            ? 'Show savings balance'
                            : 'Hide savings balance',
                        child: GestureDetector(
                          onTap: () => setState(() => _hidden = !_hidden),
                          child: Container(
                            width: 28,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0x2E000000),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: _hidden
                                  ? const Icon(
                                      Icons.visibility_off_outlined,
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
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _hidden
                          ? '₦••••••'
                          : widget.designPreview
                          ? '₦ 12,500'
                          : _formatKobo(widget.balanceKobo),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.balanceKobo > 0
                              ? 'Keep going'
                              : 'Start your health fund',
                          maxLines: 1,
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
                ],
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
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

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.balanceKobo});
  final int balanceKobo;

  @override
  Widget build(BuildContext context) {
    final guides = eligibleDashboardCoverageForBalance(balanceKobo);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF9F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'What can my balance cover?',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _DashboardV2.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CoverageDetailsScreen(balanceKobo: balanceKobo),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'See more',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: _DashboardV2.teal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SvgPicture.asset(
                        '${_DashboardV2.assets}see-more.svg',
                        width: 14,
                        height: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (guides.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Text(
                'Start saving to see the care your balance can cover.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _DashboardV2.muted,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  for (final guide in guides) _CoverageTile(guide: guide),
                ];
                if (constraints.maxWidth < 315 && tiles.length >= 3) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var index = 0; index < tiles.length; index++) ...[
                          if (index > 0) const SizedBox(width: 6),
                          SizedBox(width: 106, child: tiles[index]),
                        ],
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < tiles.length; index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(child: tiles[index]),
                    ],
                  ],
                );
              },
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
    constraints: const BoxConstraints(minHeight: 75),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (guide.title == 'Basic tests')
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    guide.title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      height: 1.25,
                      color: _DashboardV2.muted,
                    ),
                  ),
                )
              else
                Text(
                  guide.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    height: 1.25,
                    color: _DashboardV2.muted,
                  ),
                ),
              if (guide.title == 'Basic tests')
                const Text(
                  '(e.g. blood\ntest)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    height: 1.2,
                    color: _DashboardV2.muted,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                _formatNaira(guide.referenceCost),
                maxLines: 1,
                style: const TextStyle(
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
  const _PrimaryActions();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ActionButton(
          label: 'Add Money',
          asset: 'action-add-money.svg',
          color: _DashboardV2.paleTeal,
          onTap: () => Navigator.pushNamed(context, AppRoute.savings.path),
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
          onTap: () => Navigator.pushNamed(context, AppRoute.familyPocket.path),
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Column(
      children: [
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            '${_DashboardV2.assets}$asset',
            width: label == 'Family Pocket' ? 28 : 26,
            height: label == 'Family Pocket' ? 28 : 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
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
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.store,
    required this.designPreview,
    required this.developmentContributionsEnabled,
    this.onRetry,
  });
  final SavingsStore store;
  final bool designPreview;
  final bool developmentContributionsEnabled;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _DashboardV2.navy,
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pushNamed(context, AppRoute.activity.path),
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
      ),
      const SizedBox(height: 10),
      if (designPreview) ...[
        const _ActivityRow(
          title: 'Savings Contribution',
          subtitle: 'Today, 9:14 AM',
          amount: '+ ₦500',
          icon: 'activity-family.svg',
        ),
        const _ActivityRow(
          title: 'Clinic Payment',
          subtitle: 'Yesterday, 4:21 PM',
          amount: '- ₦2,000',
          icon: 'activity-clinic.svg',
          debit: true,
          divider: true,
        ),
        const _ActivityRow(
          title: 'Family Pocket Contribution',
          subtitle: 'Sept 10, 2026',
          amount: '+ ₦500',
          icon: 'activity-family.svg',
          divider: true,
        ),
      ] else if (store.contributionLoadStatus == ContributionLoadStatus.loading)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        )
      else if (store.contributionLoadStatus == ContributionLoadStatus.failure)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(child: Text('We could not load your activity.')),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        )
      else if (!developmentContributionsEnabled || store.contributions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 16),
          child: Text(
            'No recent activity yet.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: _DashboardV2.muted,
            ),
          ),
        )
      else
        for (
          var index = 0;
          index < store.contributions.length && index < 3;
          index++
        )
          _ActivityRow(
            title: 'Savings Contribution',
            subtitle: _activityDate(store.contributions[index].createdAt),
            amount: '+${_formatKobo(store.contributions[index].amountKobo)}',
            icon: 'activity-family.svg',
            divider: index > 0,
          ),
    ],
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    this.debit = false,
    this.divider = false,
  });
  final String title;
  final String subtitle;
  final String amount;
  final String icon;
  final bool debit;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 60),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
    decoration: BoxDecoration(
      border: divider
          ? const Border(top: BorderSide(color: _DashboardV2.divider))
          : null,
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: debit
              ? _DashboardV2.palePink
              : _DashboardV2.paleTeal,
          child: SvgPicture.asset(
            '${_DashboardV2.assets}$icon',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _DashboardV2.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
        const SizedBox(width: 8),
        Text(
          amount,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: debit ? _DashboardV2.navy : _DashboardV2.teal,
          ),
        ),
      ],
    ),
  );
}

String _firstName(String fullName) {
  final trimmed = fullName.trim();
  return trimmed.isEmpty ? 'there' : trimmed.split(RegExp(r'\s+')).first;
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
