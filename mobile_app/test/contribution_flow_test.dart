import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/profile/domain/user_profile.dart';
import 'package:healthpocket/features/savings/domain/personal_health_pocket.dart';
import 'package:healthpocket/features/savings/domain/savings_plan.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

void main() {
  test(
    'development contributions are idempotent, derived, ordered and restored',
    () async {
      final auth = InMemoryAuthRepository();
      final contributions = _MemoryContributionRepository();
      final appState = AppState(
        authRepository: auth,
        pinRepository: SecureAppPinRepository(
          storage: MemorySecureValueStore(),
        ),
        profileRepository: _profileRepository(),
        savingsRepository: _savingsRepository(),
        contributionRepository: contributions,
        developmentContributionsEnabled: true,
      );

      final result = await auth.signInWithEmail(
        email: 'amara@example.com',
        password: 'secure-password',
      );
      await appState.acceptAuthentication(result);
      await _flushEvents();

      const firstKey = '1111111111111111';
      await appState.recordDevelopmentContribution(
        amountNaira: 5000,
        idempotencyKey: firstKey,
      );
      await appState.recordDevelopmentContribution(
        amountNaira: 7500,
        idempotencyKey: '2222222222222222',
      );
      await appState.recordDevelopmentContribution(
        amountNaira: 5000,
        idempotencyKey: firstKey,
      );
      await _flushEvents();

      expect(appState.savingsStore.contributions, hasLength(2));
      expect(appState.savingsStore.developmentBalanceKobo, 1250000);
      expect(
        appState.savingsStore.contributions.map((item) => item.amountKobo),
        [750000, 500000],
      );

      appState.dispose();
      final restoredState = AppState(
        authRepository: auth,
        pinRepository: SecureAppPinRepository(
          storage: MemorySecureValueStore(),
        ),
        profileRepository: _profileRepository(),
        savingsRepository: _savingsRepository(),
        contributionRepository: contributions,
        developmentContributionsEnabled: true,
      );
      addTearDown(restoredState.dispose);
      addTearDown(auth.dispose);
      addTearDown(contributions.dispose);

      await restoredState.resolveStartup();
      await _flushEvents();
      expect(restoredState.savingsStore.contributions, hasLength(2));
      expect(restoredState.savingsStore.developmentBalanceKobo, 1250000);

      await restoredState.signOut();
      expect(restoredState.savingsStore.contributions, isEmpty);
      expect(
        restoredState.savingsStore.contributionLoadStatus,
        ContributionLoadStatus.idle,
      );
      expect(restoredState.savingsStore.developmentBalanceKobo, 0);
    },
  );

  test('invalid development amounts and request keys fail safely', () async {
    final auth = InMemoryAuthRepository();
    final contributions = _MemoryContributionRepository();
    final appState = AppState(
      authRepository: auth,
      pinRepository: SecureAppPinRepository(storage: MemorySecureValueStore()),
      profileRepository: _profileRepository(),
      savingsRepository: _savingsRepository(),
      contributionRepository: contributions,
      developmentContributionsEnabled: true,
    );
    addTearDown(appState.dispose);
    addTearDown(auth.dispose);
    addTearDown(contributions.dispose);

    final result = await auth.signInWithEmail(
      email: 'amara@example.com',
      password: 'secure-password',
    );
    await appState.acceptAuthentication(result);

    for (final amount in [0, -1, 1000000001]) {
      await expectLater(
        appState.recordDevelopmentContribution(
          amountNaira: amount,
          idempotencyKey: '3333333333333333',
        ),
        throwsArgumentError,
      );
    }
    await expectLater(
      appState.recordDevelopmentContribution(
        amountNaira: 5000,
        idempotencyKey: 'short',
      ),
      throwsArgumentError,
    );
    expect(contributions.records, isEmpty);
  });

  test(
    'switching accounts clears and ignores the previous account stream',
    () async {
      final store = SavingsStore();
      final firstUpdates =
          StreamController<List<ContributionRecord>>.broadcast();
      final secondUpdates =
          StreamController<List<ContributionRecord>>.broadcast();
      addTearDown(store.dispose);
      addTearDown(firstUpdates.close);
      addTearDown(secondUpdates.close);

      store.watchPersonalContributions(
        userId: 'first-user',
        personalHealthPocketId: 'personal-first-user',
        streamFactory: () => firstUpdates.stream,
      );
      firstUpdates.add([
        _recordFor(
          userId: 'first-user',
          key: 'aaaaaaaaaaaaaaaa',
          amountKobo: 100000,
        ),
      ]);
      await _flushEvents();
      expect(store.developmentBalanceKobo, 100000);

      store.watchPersonalContributions(
        userId: 'second-user',
        personalHealthPocketId: 'personal-second-user',
        streamFactory: () => secondUpdates.stream,
      );
      expect(store.contributions, isEmpty);
      firstUpdates.add([
        _recordFor(
          userId: 'first-user',
          key: 'bbbbbbbbbbbbbbbb',
          amountKobo: 200000,
        ),
      ]);
      secondUpdates.add([
        _recordFor(
          userId: 'second-user',
          key: 'cccccccccccccccc',
          amountKobo: 300000,
        ),
      ]);
      await _flushEvents();

      expect(store.contributions, hasLength(1));
      expect(store.contributions.single.contributorUserId, 'second-user');
      expect(store.developmentBalanceKobo, 300000);
    },
  );

  test('a failed contribution stream can be retried', () async {
    final store = SavingsStore();
    var attempts = 0;
    addTearDown(store.dispose);
    store.watchPersonalContributions(
      userId: 'demo-user',
      personalHealthPocketId: 'personal-demo-user',
      streamFactory: () {
        attempts++;
        return attempts == 1
            ? Stream.error(StateError('offline'))
            : Stream.value(const []);
      },
    );
    await _flushEvents();
    expect(store.contributionLoadStatus, ContributionLoadStatus.failure);

    store.retryContributionLoad();
    await _flushEvents();
    expect(store.contributionLoadStatus, ContributionLoadStatus.ready);
    expect(store.contributions, isEmpty);
  });

  test('dashboard refresh reloads profile, plan and contributions', () async {
    final auth = InMemoryAuthRepository();
    final profiles = _profileRepository() as _MemoryProfileRepository;
    final savings = _savingsRepository() as _MemorySavingsRepository;
    final contributions = _MemoryContributionRepository();
    final appState = AppState(
      authRepository: auth,
      profileRepository: profiles,
      savingsRepository: savings,
      contributionRepository: contributions,
      developmentContributionsEnabled: true,
    );
    addTearDown(appState.dispose);
    addTearDown(auth.dispose);
    addTearDown(contributions.dispose);

    final result = await auth.signInWithEmail(
      email: 'amara@example.com',
      password: 'secure-password',
    );
    await appState.acceptAuthentication(result);
    await _flushEvents();

    profiles.data = UserProfileDocumentData(
      profile: profiles.data.profile.copyWith(fullName: 'Amara Nwosu'),
      notifications: profiles.data.notifications,
      kycStatus: profiles.data.kycStatus,
    );
    savings.plan = savings.plan.copyWith(contributionAmount: 9000);
    await contributions.recordDevelopmentContribution(
      const ContributionRecord(
        id: 'dev_demo-user_dddddddddddddddd',
        contributorUserId: 'demo-user',
        personalHealthPocketId: 'personal-demo-user',
        savingsPlanId: 'personal-plan-demo-user',
        amountKobo: 900000,
        currency: 'NGN',
        status: ContributionStatus.recorded,
        origin: ContributionOrigin.devSimulation,
        moneyMovement: false,
        idempotencyKey: 'dddddddddddddddd',
        createdAt: null,
      ),
    );

    await appState.refreshDashboard();

    expect(appState.profileStore.profile.fullName, 'Amara Nwosu');
    expect(appState.savingsStore.plan?.contributionAmount, 9000);
    expect(appState.savingsStore.developmentBalanceKobo, 900000);
    expect(contributions.getCalls, 1);
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

ContributionRecord _recordFor({
  required String userId,
  required String key,
  required int amountKobo,
}) => ContributionRecord(
  id: 'dev_${userId}_$key',
  contributorUserId: userId,
  personalHealthPocketId: 'personal-$userId',
  savingsPlanId: 'personal-plan-$userId',
  amountKobo: amountKobo,
  currency: 'NGN',
  status: ContributionStatus.recorded,
  origin: ContributionOrigin.devSimulation,
  moneyMovement: false,
  idempotencyKey: key,
  createdAt: DateTime.utc(2026, 1, 1),
);

ProfileRepository _profileRepository() => _MemoryProfileRepository(
  UserProfileDocumentData(
    profile: UserProfile(
      fullName: 'Amara Okafor',
      email: 'amara@example.com',
      phoneNumber: '',
      stateOfResidence: 'Lagos',
      memberSince: DateTime(2026, 1, 1),
      emailVerified: true,
    ),
    notifications: const NotificationPreferences(
      savingsReminders: true,
      familyActivity: true,
      healthReminders: true,
      productUpdates: false,
    ),
    kycStatus: KycStatus.notStarted,
  ),
);

SavingsRepository _savingsRepository() => _MemorySavingsRepository(
  PersonalHealthPocket(
    id: 'personal-demo-user',
    userId: 'demo-user',
    currency: 'NGN',
    status: PersonalHealthPocketStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  SavingsPlan(
    id: 'personal-plan-demo-user',
    contributionAmount: 5000,
    frequency: SavingsFrequency.weekly,
    startDate: DateTime(2026, 1, 1),
    status: SavingsPlanStatus.active,
  ),
);

class _MemoryProfileRepository implements ProfileRepository {
  _MemoryProfileRepository(this.data);

  UserProfileDocumentData data;

  @override
  Future<UserProfileDocumentData?> getProfile(String userId) async => data;

  @override
  Future<void> saveProfile({
    required String userId,
    required UserProfile profile,
    required NotificationPreferences notifications,
  }) async {
    data = UserProfileDocumentData(
      profile: profile,
      notifications: notifications,
      kycStatus: KycStatus.notStarted,
    );
  }

  @override
  Stream<UserProfileDocumentData?> watchProfile(String userId) =>
      Stream.value(data);
}

class _MemorySavingsRepository implements SavingsRepository {
  _MemorySavingsRepository(this.pocket, this.plan);

  PersonalHealthPocket pocket;
  SavingsPlan plan;

  @override
  Future<PersonalHealthPocket?> getPersonalPocket(String userId) async =>
      pocket.userId == userId ? pocket : null;

  @override
  Future<SavingsPlan?> getPlan(String userId) async =>
      pocket.userId == userId ? plan : null;

  @override
  Future<void> savePersonalPocket(PersonalHealthPocket value) async {
    pocket = value;
  }

  @override
  Future<void> savePlan({
    required String userId,
    required String personalHealthPocketId,
    required SavingsPlan plan,
    DateTime? nextContributionDate,
    String? fundingSourceId,
  }) async {
    this.plan = plan;
  }

  @override
  Stream<PersonalHealthPocket?> watchPersonalPocket(String userId) =>
      Stream.value(pocket.userId == userId ? pocket : null);

  @override
  Stream<SavingsPlan?> watchPlan(String userId) =>
      Stream.value(pocket.userId == userId ? plan : null);
}

class _MemoryContributionRepository implements ContributionRepository {
  final Map<String, ContributionRecord> _records = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  DateTime _timestamp = DateTime.utc(2026, 1, 1);
  int getCalls = 0;

  List<ContributionRecord> get records => List.unmodifiable(_records.values);

  @override
  Future<List<ContributionRecord>> getPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  }) async {
    getCalls++;
    return _forPocket(userId, personalHealthPocketId);
  }

  @override
  Stream<List<ContributionRecord>> watchPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  }) async* {
    yield _forPocket(userId, personalHealthPocketId);
    await for (final _ in _changes.stream) {
      yield _forPocket(userId, personalHealthPocketId);
    }
  }

  @override
  Stream<List<ContributionRecord>> watchFamilyContributions(
    String familyPocketId,
  ) => const Stream.empty();

  @override
  Future<List<ContributionRecord>> getFamilyContributions(
    String familyPocketId,
  ) async => _records.values
      .where((record) => record.familyPocketId == familyPocketId)
      .toList(growable: false);

  @override
  Future<void> recordDevelopmentContribution(
    ContributionRecord contribution,
  ) async {
    final existing = _records[contribution.id];
    if (existing != null) {
      if (existing.amountKobo != contribution.amountKobo) {
        throw StateError('Idempotency key reused with different data.');
      }
      return;
    }
    _timestamp = _timestamp.add(const Duration(seconds: 1));
    _records[contribution.id] = ContributionRecord(
      id: contribution.id,
      contributorUserId: contribution.contributorUserId,
      personalHealthPocketId: contribution.personalHealthPocketId,
      savingsPlanId: contribution.savingsPlanId,
      familyPocketId: contribution.familyPocketId,
      amountKobo: contribution.amountKobo,
      currency: contribution.currency,
      status: contribution.status,
      origin: contribution.origin,
      moneyMovement: contribution.moneyMovement,
      idempotencyKey: contribution.idempotencyKey,
      note: contribution.note,
      createdAt: _timestamp,
    );
    _changes.add(null);
  }

  @override
  Future<void> recordDevelopmentFamilyContribution(
    ContributionRecord contribution,
  ) => recordDevelopmentContribution(contribution);

  List<ContributionRecord> _forPocket(String userId, String pocketId) =>
      _records.values
          .where(
            (record) =>
                record.contributorUserId == userId &&
                record.personalHealthPocketId == pocketId,
          )
          .toList(growable: false);

  Future<void> dispose() => _changes.close();
}
