import 'package:flutter/foundation.dart';

/// Owns only application-wide UI state. Feature state belongs to its feature.
class AppState extends ChangeNotifier {
  bool _hasCompletedOnboarding = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  void completeOnboarding() {
    _hasCompletedOnboarding = true;
    notifyListeners();
  }
}
