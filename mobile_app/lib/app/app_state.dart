import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

/// Owns only application-wide UI state. Feature state belongs to its feature.
class AppState extends ChangeNotifier {
  final FamilyPocketStore familyPocketStore = FamilyPocketStore();
  final SavingsStore savingsStore = SavingsStore();
  bool _hasCompletedOnboarding = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  @override
  void dispose() {
    familyPocketStore.dispose();
    savingsStore.dispose();
    super.dispose();
  }
}
