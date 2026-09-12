import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

void main() {
  test(
    'persists and restores a Family Pocket, invite, removal and history',
    () async {
      final auth = InMemoryAuthRepository();
      final families = _MemoryFamilyPocketRepository();
      final contributions = _MemoryContributionRepository();
      await auth.signInWithEmail(
        email: 'amara@example.com',
        password: 'secure-password',
      );
      final appState = AppState(
        authRepository: auth,
        familyPocketRepository: families,
        contributionRepository: contributions,
        developmentContributionsEnabled: true,
      );
      appState.profileStore.beginRegistration(
        fullName: 'Amara Okafor',
        email: 'amara@example.com',
        phoneNumber: '',
        emailVerified: true,
      );
      appState.familyPocketStore.resetForNewUser(
        userId: 'demo-user',
        name: 'Amara Okafor',
        email: 'amara@example.com',
      );

      await appState.createFamilyPocket(
        name: 'Okafor Family Care',
        beneficiary: 'The Okafor family',
      );
      expect(appState.familyPocketStore.pockets, hasLength(1));
      expect(appState.familyPocketStore.canManageMembers, isTrue);

      await appState.inviteFamilyMember(
        name: 'Tola Okafor',
        email: 'tola@example.com',
        role: FamilyRole.contributor,
      );
      expect(
        appState.familyPocketStore.selectedPocket!.members.where(
          (member) => member.isPending,
        ),
        hasLength(1),
      );

      const key = 'familyrecord0001';
      await appState.recordDevelopmentFamilyContribution(
        amountNaira: 7500,
        idempotencyKey: key,
      );
      await appState.recordDevelopmentFamilyContribution(
        amountNaira: 7500,
        idempotencyKey: key,
      );
      expect(appState.familyPocketStore.selectedContributions, hasLength(1));
      expect(appState.familyPocketStore.selectedBalanceKobo, 750000);

      final pocketId = appState.familyPocketStore.selectedPocket!.id;
      families.addAcceptedContributor(
        pocketId: pocketId,
        userId: 'contributor-1',
        name: 'Chidi Okafor',
      );
      contributions.seed(
        ContributionRecord(
          id: 'historical-family-record',
          contributorUserId: 'contributor-1',
          familyPocketId: pocketId,
          contributorName: 'Chidi Okafor',
          amountKobo: 250000,
          currency: 'NGN',
          status: ContributionStatus.recorded,
          origin: ContributionOrigin.devSimulation,
          moneyMovement: false,
          idempotencyKey: 'historicalrecord1',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await appState.refreshFamilyPockets();
      await appState.removeFamilyContributor('contributor-1');

      expect(
        appState.familyPocketStore.selectedPocket!.members.any(
          (member) => member.id == 'contributor-1',
        ),
        isFalse,
      );
      expect(
        appState.familyPocketStore.selectedContributions.any(
          (record) => record.contributorUserId == 'contributor-1',
        ),
        isTrue,
      );
      expect(appState.familyPocketStore.selectedBalanceKobo, 1000000);

      appState.dispose();
      final restored = AppState(
        authRepository: auth,
        familyPocketRepository: families,
        contributionRepository: contributions,
        developmentContributionsEnabled: true,
      );
      addTearDown(restored.dispose);
      addTearDown(auth.dispose);
      await restored.refreshFamilyPockets();

      expect(restored.familyPocketStore.pockets, hasLength(1));
      expect(restored.familyPocketStore.selectedContributions, hasLength(2));
      expect(restored.familyPocketStore.selectedBalanceKobo, 1000000);
    },
  );
}

class _MemoryFamilyPocketRepository implements FamilyPocketRepository {
  final List<FamilyPocket> _pockets = [];
  final Map<String, List<FamilyInvitation>> _invitations = {};

  @override
  Future<List<FamilyPocket>> getPocketsForUser(String userId) async => _pockets
      .where((pocket) => pocket.members.any((member) => member.id == userId))
      .map((pocket) {
        final invitations = _invitations[pocket.id] ?? const [];
        return pocket.copyWith(
          members: [
            ...pocket.members,
            ...invitations.map(
              (invite) => FamilyMember(
                id: invite.id,
                name: invite.name,
                email: invite.email,
                role: invite.role,
                isPending: true,
              ),
            ),
          ],
        );
      })
      .toList(growable: false);

  @override
  Future<void> createPocket({
    required FamilyPocket pocket,
    required String createdBy,
    required FamilyMembership adminMembership,
  }) async {
    _pockets.add(
      pocket.copyWith(
        members: [
          FamilyMember(
            id: adminMembership.id,
            name: adminMembership.name,
            email: '',
            role: FamilyRole.admin,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> createInvitation(FamilyInvitation invitation) async {
    _invitations.putIfAbsent(invitation.pocketId, () => []).add(invitation);
  }

  void addAcceptedContributor({
    required String pocketId,
    required String userId,
    required String name,
  }) {
    final index = _pockets.indexWhere((pocket) => pocket.id == pocketId);
    final pocket = _pockets[index];
    _pockets[index] = pocket.copyWith(
      members: [
        ...pocket.members,
        FamilyMember(
          id: userId,
          name: name,
          email: '',
          role: FamilyRole.contributor,
        ),
      ],
    );
  }

  @override
  Future<void> markContributorRemoved({
    required String pocketId,
    required String memberId,
  }) async {
    final index = _pockets.indexWhere((pocket) => pocket.id == pocketId);
    final pocket = _pockets[index];
    _pockets[index] = pocket.copyWith(
      members: pocket.members
          .where((member) => member.id != memberId)
          .toList(growable: false),
    );
  }

  @override
  Stream<List<FamilyMembership>> watchMembershipsForUser(String userId) =>
      const Stream.empty();

  @override
  Stream<List<FamilyMembership>> watchMembers(String pocketId) =>
      const Stream.empty();

  @override
  Stream<FamilyPocket?> watchPocket(String pocketId) => const Stream.empty();
}

class _MemoryContributionRepository implements ContributionRepository {
  final Map<String, ContributionRecord> _records = {};
  DateTime _time = DateTime.utc(2026, 1, 1);

  void seed(ContributionRecord record) => _records[record.id] = record;

  @override
  Future<List<ContributionRecord>> getFamilyContributions(
    String familyPocketId,
  ) async => _records.values
      .where((record) => record.familyPocketId == familyPocketId)
      .toList(growable: false);

  @override
  Future<List<ContributionRecord>> getPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  }) async => const [];

  @override
  Future<void> recordDevelopmentFamilyContribution(
    ContributionRecord contribution,
  ) async {
    if (_records.containsKey(contribution.id)) return;
    _time = _time.add(const Duration(seconds: 1));
    _records[contribution.id] = ContributionRecord(
      id: contribution.id,
      contributorUserId: contribution.contributorUserId,
      familyPocketId: contribution.familyPocketId,
      contributorName: contribution.contributorName,
      amountKobo: contribution.amountKobo,
      currency: contribution.currency,
      status: contribution.status,
      origin: contribution.origin,
      moneyMovement: contribution.moneyMovement,
      idempotencyKey: contribution.idempotencyKey,
      createdAt: _time,
    );
  }

  @override
  Future<void> recordDevelopmentContribution(
    ContributionRecord contribution,
  ) async {}

  @override
  Stream<List<ContributionRecord>> watchFamilyContributions(
    String familyPocketId,
  ) => const Stream.empty();

  @override
  Stream<List<ContributionRecord>> watchPersonalContributions({
    required String userId,
    required String personalHealthPocketId,
  }) => const Stream.empty();
}
