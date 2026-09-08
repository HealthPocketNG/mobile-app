import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/savings/data/mock_savings_data.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

class SavingsStore extends ChangeNotifier {
  SavingsStore()
    : _plan = MockSavingsData.plan,
      _contributions = List.of(MockSavingsData.contributions);

  static const _personalPlanId = 'personal-savings-plan';

  SavingsPlan? _plan;
  final List<SavingsContribution> _contributions;

  SavingsPlan? get plan => _plan;
  List<SavingsContribution> get contributions =>
      List.unmodifiable(_contributions);
  int get currentBalance => _contributions
      .where((item) => item.status == SavingsContributionStatus.completed)
      .fold(0, (total, item) => total + item.amount);

  void resetForOnboarding() {
    _plan = null;
    _contributions.clear();
    notifyListeners();
  }

  void configurePlan({
    required int contributionAmount,
    required String frequency,
    required DateTime startDate,
  }) {
    _plan = SavingsPlan(
      id: _plan?.id ?? _personalPlanId,
      contributionAmount: contributionAmount,
      frequency: frequency,
      startDate: startDate,
      status: _plan?.status ?? SavingsPlanStatus.active,
    );
    notifyListeners();
  }

  void saveOnboardingPlan({
    required int contributionAmount,
    required String frequency,
    required DateTime startDate,
  }) {
    _plan = SavingsPlan(
      id: _personalPlanId,
      contributionAmount: contributionAmount,
      frequency: frequency,
      startDate: startDate,
      status: SavingsPlanStatus.active,
    );
    notifyListeners();
  }

  void togglePlan() {
    final currentPlan = _plan;
    if (currentPlan == null) return;
    _plan = currentPlan.copyWith(
      status: currentPlan.status == SavingsPlanStatus.paused
          ? SavingsPlanStatus.active
          : SavingsPlanStatus.paused,
    );
    notifyListeners();
  }

  void recordContribution(int amount) {
    final currentPlan = _plan;
    if (currentPlan == null) return;
    _contributions.insert(
      0,
      SavingsContribution(
        id: 'contribution-${DateTime.now().microsecondsSinceEpoch}',
        planId: currentPlan.id,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
