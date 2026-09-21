import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/dashboard/data/mock_dashboard_data.dart';
import 'package:healthpocket/features/dashboard/domain/coverage_guide.dart';
import 'package:healthpocket/features/dashboard/presentation/coverage_details_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          const SnackBar(content: Text('Updates could not be refreshed. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([savingsStore, profileStore]),
    builder: (context, child) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                sliver: SliverList.list(children: [
                  _DashboardHeader(profileStore: profileStore),
                  const SizedBox(height: 22),
                  _SavingsBalanceCard(
                    store: savingsStore,
                    developmentContributionsEnabled: developmentContributionsEnabled,
                  ),
                  const SizedBox(height: 14),
                  _CoveragePanel(balanceKobo: savingsStore.developmentBalanceKobo),
                  const SizedBox(height: 20),
                  _PrimaryActions(
                    onAddMoney: () => Navigator.pushNamed(context, AppRoute.savings.path),
                    onFamilyPocket: () => Navigator.pushNamed(context, AppRoute.familyPocket.path),
                  ),
                  const SizedBox(height: 28),
                  _RecentActivity(
                    store: savingsStore,
                    developmentContributionsEnabled: developmentContributionsEnabled,
                    onRetry: onRetryContributions,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profileStore});
  final ProfileStore profileStore;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Greetings ${_firstName(profileStore.profile.fullName)},',
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          'There’s a healthier\ntomorrow ahead.',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
      ])),
      IconButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have no new notifications.'))),
        icon: const Badge(
          smallSize: 8,
          backgroundColor: AppColors.secondary,
          child: Icon(LucideIcons.bell, size: 27),
        ),
        tooltip: 'Notifications',
      ),
      const SizedBox(width: 8),
      Semantics(
        label: '${_firstName(profileStore.profile.fullName)} profile',
        child: const CircleAvatar(radius: 23, backgroundColor: Color(0xFFD7F6F3), child: Icon(LucideIcons.userRound, color: AppColors.primaryDark, size: 27)),
      ),
    ]);
  }
}

class _SavingsBalanceCard extends StatefulWidget {
  const _SavingsBalanceCard({required this.store, required this.developmentContributionsEnabled});
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
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(context, AppRoute.savings.path),
        child: Ink(
          height: 145,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF09A99F), Color(0xFF006A6A)]),
            boxShadow: const [BoxShadow(color: Color(0x2B007A76), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Stack(children: [
            Positioned(
              right: -26,
              top: -66,
              child: Container(
                width: 126,
                height: 126,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .10), width: 20),
                ),
              ),
            ),
            Positioned(
              right: -2,
              top: -32,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Total Savings', style: TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(width: 6),
                Tooltip(
                  message: _isBalanceHidden ? 'Show savings balance' : 'Hide savings balance',
                  child: Semantics(
                    button: true,
                    label: _isBalanceHidden ? 'Show savings balance' : 'Hide savings balance',
                    child: GestureDetector(
                      onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                      child: Icon(
                        _isBalanceHidden ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                _isBalanceHidden ? '₦••••••' : _formatKobo(balanceKobo),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1),
              ),
              const Spacer(),
              Row(children: [
                Text(widget.developmentContributionsEnabled && balanceKobo > 0 ? 'Keep going 💪' : 'Start your health fund 💪', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                const CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(LucideIcons.arrowRight, color: AppColors.primaryDark, size: 20)),
              ]),
            ]),
          ]),
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
    padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
    decoration: BoxDecoration(color: const Color(0xFFE7FAF8), borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Row(children: [
        Expanded(child: Text('What can my balance cover?', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CoverageDetailsScreen(balanceKobo: balanceKobo),
          )),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
          label: const Text('See more'), icon: const Icon(LucideIcons.arrowRight, size: 16), iconAlignment: IconAlignment.end,
        ),
      ]),
      const SizedBox(height: 8),
      if (eligibleGuides.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Text(message, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
        )
      else
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: eligibleGuides.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _CoverageTile(
              guide: eligibleGuides[index],
              balanceKobo: balanceKobo,
            ),
          ),
        ),
    ]),
  );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.guide, required this.balanceKobo});
  final CoverageGuide guide;
  final int balanceKobo;
  @override
  Widget build(BuildContext context) => Container(
    width: 154, height: 112, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SvgPicture.asset(guide.asset, width: 46, height: 46, fit: BoxFit.contain),
      const SizedBox(height: 3),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(guide.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.05)),
        const Spacer(),
        Text(_formatNaira(guide.referenceCost), maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: balanceKobo >= guide.referenceCost * 100 ? AppColors.success : AppColors.primaryDark)),
      ])),
    ]),
  );
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.onAddMoney, required this.onFamilyPocket});
  final VoidCallback onAddMoney;
  final VoidCallback onFamilyPocket;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _ActionButton(label: 'Add Money', icon: LucideIcons.plus, color: const Color(0xFFDDF8F6), onTap: onAddMoney)),
    const SizedBox(width: 12),
    Expanded(child: _ActionButton(label: 'Scan to Pay', icon: LucideIcons.scan, color: const Color(0xFFFFEAEE), iconColor: AppColors.secondary, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan to Pay will be available soon.'))))),
    const SizedBox(width: 12),
    Expanded(child: _ActionButton(label: 'Family Pocket', icon: LucideIcons.usersRound, color: const Color(0xFFDDF8F6), onTap: onFamilyPocket)),
  ]);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap, this.iconColor});
  final String label;
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true, label: label,
    child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Column(children: [
      Ink(height: 62, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: Center(child: Icon(icon, color: iconColor ?? AppColors.primary, size: 30))),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ])),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.store, required this.developmentContributionsEnabled, this.onRetry});
  final SavingsStore store;
  final bool developmentContributionsEnabled;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const Spacer(),
      TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoute.activity.path),
        child: const Text('See all'),
      ),
    ]),
    const SizedBox(height: 4),
    if (store.contributionLoadStatus == ContributionLoadStatus.loading)
      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
    else if (store.contributionLoadStatus == ContributionLoadStatus.failure)
      _ActivityFailure(onRetry: onRetry)
    else if (!developmentContributionsEnabled || store.contributions.isEmpty)
      const _EmptyActivity()
    else
      ...store.contributions.take(3).map((activity) => _ActivityTile(amountKobo: activity.amountKobo, date: activity.createdAt)),
  ]);
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Image.asset('assets/activity/no-activity.png', height: 104, fit: BoxFit.contain),
      const Text('No activity yet', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      const Text('Your savings activity will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
    ]),
  );
}

class _ActivityFailure extends StatelessWidget {
  const _ActivityFailure({this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
    child: Row(children: [
      const Expanded(child: Text('We could not load your activity.', style: TextStyle(color: AppColors.inkMuted))),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.amountKobo, required this.date});
  final int amountKobo;
  final DateTime? date;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      const CircleAvatar(radius: 20, backgroundColor: AppColors.primarySoft, child: Icon(Icons.savings_outlined, color: AppColors.primary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Savings Contribution', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(_activityDate(date), style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ])),
      Text('+${_formatKobo(amountKobo)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
    ]),
  );
}

String _firstName(String fullName) {
  final value = fullName.trim();
  if (value.isEmpty) return MockDashboardData.firstName;
  return value.split(RegExp(r'\s+')).first;
}

String _formatNaira(int amount) => '₦${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
String _formatKobo(int amountKobo) {
  final naira = amountKobo ~/ 100;
  final kobo = amountKobo.remainder(100).abs();
  return kobo == 0 ? _formatNaira(naira) : '${_formatNaira(naira)}.${kobo.toString().padLeft(2, '0')}';
}
String _activityDate(DateTime? date) {
  if (date == null) return 'Development record • Saving… • No money moved';
  final difference = DateTime.now().difference(date).inDays;
  if (difference <= 0) return 'Development record • Today • No money moved';
  if (difference == 1) return 'Development record • Yesterday • No money moved';
  return 'Development record • $difference days ago • No money moved';
}
