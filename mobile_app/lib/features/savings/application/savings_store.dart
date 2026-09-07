import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/savings/data/mock_savings_data.dart';
import 'package:healthpocket/features/savings/domain/savings_goal.dart';

class SavingsStore extends ChangeNotifier {
  SavingsStore()
    : _goals = List.of(MockSavingsData.goals),
      _contributions = List.of(MockSavingsData.contributions);

  final List<SavingsGoal> _goals;
  final List<SavingsContribution> _contributions;

  List<SavingsGoal> get goals => List.unmodifiable(_goals);
  List<SavingsContribution> get contributions =>
      List.unmodifiable(_contributions);
  int get totalSaved =>
      _goals.fold(0, (total, goal) => total + goal.currentAmount);
  int get totalTarget =>
      _goals.fold(0, (total, goal) => total + goal.targetAmount);

  void createGoal({
    required String title,
    required int targetAmount,
    required String frequency,
  }) {
    _goals.insert(
      0,
      SavingsGoal(
        id: 'goal-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        targetAmount: targetAmount,
        currentAmount: 0,
        frequency: frequency,
        status: SavingsGoalStatus.active,
      ),
    );
    notifyListeners();
  }

  void updateGoal(
    SavingsGoal goal, {
    required String title,
    required int targetAmount,
    required String frequency,
  }) {
    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) return;
    _goals[index] = goal.copyWith(
      title: title,
      targetAmount: targetAmount,
      frequency: frequency,
    );
    notifyListeners();
  }

  void toggleGoal(SavingsGoal goal) {
    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index == -1 || goal.status == SavingsGoalStatus.completed) return;
    _goals[index] = goal.copyWith(
      status: goal.status == SavingsGoalStatus.paused
          ? SavingsGoalStatus.active
          : SavingsGoalStatus.paused,
    );
    notifyListeners();
  }

  void recordContribution(SavingsGoal goal, int amount) {
    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index == -1 || goal.status != SavingsGoalStatus.active) return;
    final updatedAmount = goal.currentAmount + amount;
    _goals[index] = goal.copyWith(
      currentAmount: updatedAmount,
      status: updatedAmount >= goal.targetAmount
          ? SavingsGoalStatus.completed
          : SavingsGoalStatus.active,
    );
    _contributions.insert(
      0,
      SavingsContribution(
        id: 'contribution-${DateTime.now().microsecondsSinceEpoch}',
        goalId: goal.id,
        goalTitle: goal.title,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
