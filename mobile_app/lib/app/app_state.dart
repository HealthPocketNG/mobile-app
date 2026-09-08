import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

/// Owns only application-wide UI state. Feature state belongs to its feature.
class AppState extends ChangeNotifier {
  final FamilyPocketStore familyPocketStore = FamilyPocketStore();
  final ProfileStore profileStore = ProfileStore();
  final SavingsStore savingsStore = SavingsStore();
  bool _hasCompletedOnboarding = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  void beginRegistration() {
    _hasCompletedOnboarding = false;
    savingsStore.resetForOnboarding();
    familyPocketStore.resetForNewUser(
      name: profileStore.profile.fullName,
      email: profileStore.profile.email,
    );
    notifyListeners();
  }

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  @override
  void dispose() {
    familyPocketStore.dispose();
    profileStore.dispose();
    savingsStore.dispose();
    super.dispose();
  }
}
