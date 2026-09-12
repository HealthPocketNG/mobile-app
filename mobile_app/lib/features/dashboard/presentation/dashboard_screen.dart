import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/dashboard/data/mock_dashboard_data.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

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
    final refresh = onRefresh;
    if (refresh == null) return;
    try {
      await refresh();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Updates could not be refreshed. Check your connection and try again.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    _DashboardHeader(profileStore: profileStore),
                    const SizedBox(height: AppSpacing.lg),
                    _BalanceCard(
                      store: savingsStore,
                      developmentContributionsEnabled:
                          developmentContributionsEnabled,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _CoverageSection(
                      balanceKobo: savingsStore.developmentBalanceKobo,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SavingsPlanCard(plan: savingsStore.plan),
                    const SizedBox(height: AppSpacing.md),
                    const _FamilyPocketCard(),
                    const SizedBox(height: AppSpacing.xl),
                    _ActivitySection(
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
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profileStore});

  final ProfileStore profileStore;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
        ? 'Good afternoon,'
        : 'Good evening,';
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primarySoft,
          child: Icon(
            Icons.person_rounded,
            color: AppColors.primaryDark,
            size: 31,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                '${_firstName(profileStore.profile.fullName)} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have no new notifications.')),
          ),
          icon: const Icon(Icons.notifications_none_rounded, size: 28),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.store,
    required this.developmentContributionsEnabled,
  });

  final SavingsStore store;
  final bool developmentContributionsEnabled;

  @override
  Widget build(BuildContext context) {
    final balanceKobo = store.developmentBalanceKobo;
    final plan = store.plan;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF078A7C), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26045E5B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  developmentContributionsEnabled
                      ? 'Development savings balance'
                      : 'Health savings balance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF71F1C9),
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatKobo(balanceKobo),
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            developmentContributionsEnabled
                ? balanceKobo == 0
                      ? 'Development record — no money moved.'
                      : 'Simulated records only — no money moved.'
                : 'Savings balance is not enabled in this build.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _BalanceMetric(
                  label: 'Savings plan',
                  value: plan == null
                      ? 'Not set'
                      : '${_formatNaira(plan.contributionAmount)} ${plan.frequency.label.toLowerCase()}',
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white24),
              Expanded(
                child: _BalanceMetric(
                  label: 'Contributions',
                  value: developmentContributionsEnabled
                      ? '${store.contributions.length} development records'
                      : 'Not enabled',
                ),
              ),
            ],
          ),
          if (developmentContributionsEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoute.savings.path),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  balanceKobo == 0
                      ? 'Add development record'
                      : 'Add another development record',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageSection extends StatelessWidget {
  const _CoverageSection({required this.balanceKobo});

  final int balanceKobo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What your balance can help cover',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Illustrative costs only—not insurance or a provider quote.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MockDashboardData.coverageGuides.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => _CoverageCard(
              guide: MockDashboardData.coverageGuides[index],
              balanceKobo: balanceKobo,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.guide, required this.balanceKobo});

  final HealthcareCostGuide guide;
  final int balanceKobo;

  @override
  Widget build(BuildContext context) {
    final referenceCostKobo = guide.referenceCost * 100;
    final enough = balanceKobo >= referenceCostKobo;
    final differenceKobo = referenceCostKobo - balanceKobo;
    return Container(
      width: 145,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: guide.color.withValues(alpha: 0.12),
            child: Icon(guide.icon, color: guide.color, size: 21),
          ),
          const Spacer(),
          Text(
            guide.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'Estimate ${_formatNaira(guide.referenceCost)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            balanceKobo == 0
                ? 'Start saving'
                : enough
                ? 'Within your balance'
                : '${_formatKobo(differenceKobo)} more may help',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enough ? AppColors.success : AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsPlanCard extends StatelessWidget {
  const _SavingsPlanCard({required this.plan});

  final SavingsPlan? plan;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, AppRoute.savings.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.savings_outlined,
                  color: AppColors.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPlan == null
                          ? 'Set up your savings plan'
                          : '${_formatNaira(currentPlan.contributionAmount)} ${currentPlan.frequency.label.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      currentPlan == null
                          ? 'Choose an amount and a comfortable schedule.'
                          : currentPlan.status == SavingsPlanStatus.paused
                          ? 'Savings plan paused'
                          : 'Your savings plan is active',
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyPocketCard extends StatelessWidget {
  const _FamilyPocketCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondarySoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, AppRoute.familyPocket.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.groups_2_outlined,
                  color: AppColors.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Pocket',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('Save together for your family’s healthcare.'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.store,
    required this.developmentContributionsEnabled,
    this.onRetry,
  });

  final SavingsStore store;
  final bool developmentContributionsEnabled;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent activity',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!developmentContributionsEnabled)
          const Text(
            'Savings activity is not enabled in this build.',
            style: TextStyle(color: AppColors.inkMuted),
          )
        else if (store.contributionLoadStatus == ContributionLoadStatus.loading)
          const Center(child: CircularProgressIndicator())
        else if (store.contributionLoadStatus == ContributionLoadStatus.failure)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Development records could not be loaded. No balance has been assumed.',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          )
        else if (store.contributions.isEmpty)
          const Text(
            'No development records yet. No money has moved.',
            style: TextStyle(color: AppColors.inkMuted),
          )
        else
          ...store.contributions
              .take(3)
              .map(
                (activity) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(
                      Icons.south_west_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Simulated savings contribution',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_activityDate(activity.createdAt)),
                  trailing: Text(
                    '+${_formatKobo(activity.amountKobo)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

String _firstName(String fullName) {
  final value = fullName.trim();
  if (value.isEmpty) return MockDashboardData.firstName;
  return value.split(RegExp(r'\s+')).first;
}

String _formatNaira(int amount) {
  final value = amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '₦$value';
}

String _formatKobo(int amountKobo) {
  final naira = amountKobo ~/ 100;
  final kobo = amountKobo.remainder(100).abs();
  final whole = _formatNaira(naira);
  return kobo == 0 ? whole : '$whole.${kobo.toString().padLeft(2, '0')}';
}

String _activityDate(DateTime? date) {
  if (date == null) return 'Development record • Saving… • No money moved';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return 'Development record • Today • No money moved';
  if (days == 1) return 'Development record • Yesterday • No money moved';
  return 'Development record • $days days ago • No money moved';
}
