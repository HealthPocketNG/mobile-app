import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/savings/data/mock_savings_data.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';

enum ContributionLoadStatus { idle, loading, ready, failure }

class SavingsStore extends ChangeNotifier {
  SavingsStore({SavingsPlan? initialPlan})
    : _plan = initialPlan ?? MockSavingsData.plan;

  static const _personalPlanId = 'personal-savings-plan';

  SavingsPlan? _plan;
  final List<ContributionRecord> _contributions = [];
  ContributionLoadStatus _contributionLoadStatus = ContributionLoadStatus.idle;
  Object? _contributionLoadError;
  StreamSubscription<List<ContributionRecord>>? _contributionSubscription;
  Stream<List<ContributionRecord>> Function()? _contributionStreamFactory;
  String? _watchedUserId;
  String? _watchedPocketId;
  int _watchGeneration = 0;

  SavingsPlan? get plan => _plan;
  List<ContributionRecord> get contributions =>
      List.unmodifiable(_contributions);
  ContributionLoadStatus get contributionLoadStatus => _contributionLoadStatus;
  Object? get contributionLoadError => _contributionLoadError;

  int get developmentBalanceKobo => _contributions
      .where((item) => item.isEligibleForDevelopmentBalance)
      .fold(0, (total, item) => total + item.amountKobo);

  void hydrate({required SavingsPlan? plan}) {
    _plan = plan;
    clearContributionState(notify: false);
    notifyListeners();
  }

  void replacePlan(SavingsPlan plan) {
    _plan = plan;
    notifyListeners();
  }

  void resetForOnboarding() {
    _plan = null;
    clearContributionState(notify: false);
    notifyListeners();
  }

  void configurePlan({
    required int contributionAmount,
    required SavingsFrequency frequency,
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
    required SavingsFrequency frequency,
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

  void watchPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
    required Stream<List<ContributionRecord>> Function() streamFactory,
  }) {
    _watchedUserId = userId;
    _watchedPocketId = personalHealthPocketId;
    _contributionStreamFactory = streamFactory;
    _startContributionWatch();
  }

  void retryContributionLoad() {
    if (_contributionStreamFactory == null ||
        _watchedUserId == null ||
        _watchedPocketId == null) {
      return;
    }
    _startContributionWatch();
  }

  void _startContributionWatch() {
    final factory = _contributionStreamFactory;
    final userId = _watchedUserId;
    final pocketId = _watchedPocketId;
    if (factory == null || userId == null || pocketId == null) return;

    final generation = ++_watchGeneration;
    unawaited(_contributionSubscription?.cancel());
    _contributions.clear();
    _contributionLoadError = null;
    _contributionLoadStatus = ContributionLoadStatus.loading;
    notifyListeners();

    try {
      _contributionSubscription = factory().listen(
        (records) {
          if (generation != _watchGeneration) return;
          try {
            _replacePersonalContributions(
              userId: userId,
              personalHealthPocketId: pocketId,
              records: records,
            );
          } catch (error) {
            _contributions.clear();
            _contributionLoadError = error;
            _contributionLoadStatus = ContributionLoadStatus.failure;
            notifyListeners();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (generation != _watchGeneration) return;
          _contributions.clear();
          _contributionLoadError = error;
          _contributionLoadStatus = ContributionLoadStatus.failure;
          notifyListeners();
        },
      );
    } catch (error) {
      if (generation != _watchGeneration) return;
      _contributions.clear();
      _contributionLoadError = error;
      _contributionLoadStatus = ContributionLoadStatus.failure;
      notifyListeners();
    }
  }

  void replacePersonalContributions({
    required String userId,
    required String personalHealthPocketId,
    required List<ContributionRecord> records,
  }) {
    if (_watchedUserId != userId ||
        _watchedPocketId != personalHealthPocketId) {
      throw StateError('Contribution refresh does not match this account.');
    }
    _replacePersonalContributions(
      userId: userId,
      personalHealthPocketId: personalHealthPocketId,
      records: records,
    );
  }

  void _replacePersonalContributions({
    required String userId,
    required String personalHealthPocketId,
    required List<ContributionRecord> records,
  }) {
    final containsForeignRecord = records.any(
      (record) =>
          record.contributorUserId != userId ||
          record.personalHealthPocketId != personalHealthPocketId,
    );
    if (containsForeignRecord) {
      throw StateError(
        'Contribution source returned data for another account.',
      );
    }
    final ordered = List<ContributionRecord>.of(records)
      ..sort(_newestContributionFirst);
    _contributions
      ..clear()
      ..addAll(ordered);
    _contributionLoadError = null;
    _contributionLoadStatus = ContributionLoadStatus.ready;
    notifyListeners();
  }

  void clearContributionState({bool notify = true}) {
    _watchGeneration++;
    unawaited(_contributionSubscription?.cancel());
    _contributionSubscription = null;
    _contributionStreamFactory = null;
    _watchedUserId = null;
    _watchedPocketId = null;
    _contributions.clear();
    _contributionLoadError = null;
    _contributionLoadStatus = ContributionLoadStatus.idle;
    if (notify) notifyListeners();
  }

  static int _newestContributionFirst(
    ContributionRecord first,
    ContributionRecord second,
  ) {
    final firstTime = first.createdAt;
    final secondTime = second.createdAt;
    if (firstTime == null && secondTime != null) return -1;
    if (firstTime != null && secondTime == null) return 1;
    if (firstTime != null && secondTime != null) {
      final byTime = secondTime.compareTo(firstTime);
      if (byTime != 0) return byTime;
    }
    return second.id.compareTo(first.id);
  }

  @override
  void dispose() {
    _watchGeneration++;
    unawaited(_contributionSubscription?.cancel());
    super.dispose();
  }
}
