import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/contributions/domain/contribution_record.dart';
import 'package:healthpocket/features/family/data/mock_family_data.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

enum FamilyPocketLoadStatus { idle, loading, ready, failure }

class FamilyPocketStore extends ChangeNotifier {
  FamilyPocketStore()
    : _pockets = List.of(MockFamilyData.pockets),
      _contributions = List.of(MockFamilyData.contributions),
      _selectedPocketId = MockFamilyData.pockets.first.id;

  final List<FamilyPocket> _pockets;
  final List<ContributionRecord> _contributions;
  final List<FamilyInvitation> _receivedInvitations = [];
  String? _selectedPocketId;
  String _currentUserId = 'current-user';
  String _currentUserName = 'Samson Adebayo';
  FamilyPocketLoadStatus _loadStatus = FamilyPocketLoadStatus.ready;
  Object? _loadError;

  List<FamilyPocket> get pockets => List.unmodifiable(_pockets);
  List<FamilyInvitation> get receivedInvitations =>
      List.unmodifiable(_receivedInvitations);
  FamilyPocket? get selectedPocket {
    final pocketId = _selectedPocketId;
    if (pocketId == null) return null;
    return _pockets.where((pocket) => pocket.id == pocketId).firstOrNull;
  }

  List<ContributionRecord> get selectedContributions {
    final pocketId = _selectedPocketId;
    if (pocketId == null) return const [];
    return List.unmodifiable(
      _contributions.where((item) => item.familyPocketId == pocketId),
    );
  }

  int get selectedBalanceKobo => selectedContributions
      .where(
        (contribution) =>
            contribution.familyPocketId != null &&
            contribution.status == ContributionStatus.recorded &&
            contribution.origin == ContributionOrigin.devSimulation &&
            !contribution.moneyMovement &&
            contribution.currency == 'NGN' &&
            contribution.amountKobo > 0,
      )
      .fold(0, (total, contribution) => total + contribution.amountKobo);

  int balanceForPocketKobo(String pocketId) => _contributions
      .where(
        (contribution) =>
            contribution.familyPocketId == pocketId &&
            contribution.status == ContributionStatus.recorded &&
            contribution.origin == ContributionOrigin.devSimulation &&
            !contribution.moneyMovement &&
            contribution.currency == 'NGN' &&
            contribution.amountKobo > 0,
      )
      .fold(0, (total, contribution) => total + contribution.amountKobo);

  int get totalBalanceKobo => _pockets.fold(
    0,
    (total, pocket) => total + balanceForPocketKobo(pocket.id),
  );

  FamilyPocketLoadStatus get loadStatus => _loadStatus;
  Object? get loadError => _loadError;

  bool get canManageMembers =>
      selectedPocket?.members.any(
        (member) =>
            member.id == _currentUserId && member.role == FamilyRole.admin,
      ) ??
      false;

  bool get canContribute =>
      selectedPocket?.members.any(
        (member) => member.id == _currentUserId && member.canContribute,
      ) ??
      false;

  void resetForNewUser({
    String userId = 'current-user',
    required String name,
    required String email,
  }) {
    _currentUserId = userId;
    _currentUserName = name;
    _pockets.clear();
    _contributions.clear();
    _receivedInvitations.clear();
    _selectedPocketId = null;
    _loadStatus = FamilyPocketLoadStatus.idle;
    _loadError = null;
    notifyListeners();
  }

  void beginLoad() {
    _loadStatus = FamilyPocketLoadStatus.loading;
    _loadError = null;
    notifyListeners();
  }

  void hydratePersistent({
    required String userId,
    required String name,
    required String email,
    required List<FamilyPocket> pockets,
    required List<ContributionRecord> contributions,
    List<FamilyInvitation> receivedInvitations = const [],
  }) {
    final previousSelection = _selectedPocketId;
    _currentUserId = userId;
    _currentUserName = name;
    _pockets
      ..clear()
      ..addAll(pockets);
    final ordered = List<ContributionRecord>.of(contributions)
      ..sort(_newestFirst);
    _contributions
      ..clear()
      ..addAll(ordered);
    _receivedInvitations
      ..clear()
      ..addAll(receivedInvitations);
    _selectedPocketId = pockets.any((pocket) => pocket.id == previousSelection)
        ? previousSelection
        : pockets.firstOrNull?.id;
    _loadStatus = FamilyPocketLoadStatus.ready;
    _loadError = null;
    notifyListeners();
  }

  void setLoadFailure(Object error) {
    _loadStatus = FamilyPocketLoadStatus.failure;
    _loadError = error;
    notifyListeners();
  }

  void selectPocket(String pocketId) {
    if (_selectedPocketId == pocketId ||
        !_pockets.any((pocket) => pocket.id == pocketId)) {
      return;
    }
    _selectedPocketId = pocketId;
    notifyListeners();
  }

  void createPocket({required String name}) {
    final id = 'pocket-${DateTime.now().microsecondsSinceEpoch}';
    _pockets.insert(
      0,
      FamilyPocket(
        id: id,
        name: name,
        members: [
          FamilyMember(
            id: _currentUserId,
            name: _currentUserName,
            role: FamilyRole.admin,
            canContribute: true,
            isBeneficiary: false,
          ),
        ],
      ),
    );
    _selectedPocketId = id;
    notifyListeners();
  }

  bool inviteMember({
    required String name,
    required String email,
    required bool canContribute,
    required bool isBeneficiary,
  }) {
    final pocket = selectedPocket;
    if (pocket == null || !canManageMembers) return false;
    if (!canContribute && !isBeneficiary) return false;
    if (isBeneficiary &&
        pocket.reservedBeneficiaryCount >= pocket.beneficiaryLimit) {
      return false;
    }
    final index = _pockets.indexWhere((item) => item.id == pocket.id);
    _pockets[index] = pocket.copyWith(
      invitations: [
        ...pocket.invitations,
        FamilyInvitation(
          id: 'invite-${DateTime.now().microsecondsSinceEpoch}',
          pocketId: pocket.id,
          pocketName: pocket.name,
          inviteeName: name,
          email: email.toLowerCase(),
          inviterName: _currentUserName,
          canContribute: canContribute,
          isBeneficiary: isBeneficiary,
          beneficiarySlot: isBeneficiary
              ? pocket.reservedBeneficiaryCount + 1
              : null,
          status: FamilyInvitationStatus.pending,
          createdBy: _currentUserId,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        ),
      ],
    );
    notifyListeners();
    return true;
  }

  bool removeMember(String memberId) {
    final pocket = selectedPocket;
    if (pocket == null || !canManageMembers) return false;
    final member = pocket.members
        .where((item) => item.id == memberId)
        .firstOrNull;
    if (member == null ||
        member.id == _currentUserId ||
        member.role == FamilyRole.admin) {
      return false;
    }
    final index = _pockets.indexWhere((item) => item.id == pocket.id);
    _pockets[index] = pocket.copyWith(
      members: pocket.members.where((item) => item.id != memberId).toList(),
    );
    notifyListeners();
    return true;
  }

  bool respondToInvitation(String invitationId, {required bool accept}) {
    final invitation = _receivedInvitations
        .where((item) => item.id == invitationId)
        .firstOrNull;
    if (invitation == null ||
        invitation.effectiveStatus != FamilyInvitationStatus.pending) {
      return false;
    }
    _receivedInvitations.removeWhere((item) => item.id == invitationId);
    if (accept) {
      final pocket = _pockets
          .where((item) => item.id == invitation.pocketId)
          .firstOrNull;
      if (pocket != null) {
        final index = _pockets.indexOf(pocket);
        _pockets[index] = pocket.copyWith(
          members: [
            ...pocket.members,
            FamilyMember(
              id: _currentUserId,
              name: _currentUserName,
              role: FamilyRole.member,
              canContribute: invitation.canContribute,
              isBeneficiary: invitation.isBeneficiary,
              beneficiarySlot: invitation.beneficiarySlot,
            ),
          ],
        );
        _selectedPocketId = pocket.id;
      }
    }
    notifyListeners();
    return true;
  }

  bool cancelInvitation(String invitationId) {
    final pocket = selectedPocket;
    if (pocket == null || !canManageMembers) return false;
    final invitation = pocket.invitations
        .where((item) => item.id == invitationId)
        .firstOrNull;
    if (invitation == null ||
        invitation.status != FamilyInvitationStatus.pending) {
      return false;
    }
    final index = _pockets.indexOf(pocket);
    _pockets[index] = pocket.copyWith(
      invitations: pocket.invitations
          .map(
            (item) => item.id == invitationId
                ? item.copyWith(status: FamilyInvitationStatus.cancelled)
                : item,
          )
          .toList(growable: false),
    );
    notifyListeners();
    return true;
  }

  void recordContribution(int amount) {
    final pocket = selectedPocket;
    if (pocket == null) return;
    _contributions.insert(
      0,
      ContributionRecord(
        id: 'family-contribution-${DateTime.now().microsecondsSinceEpoch}',
        contributorUserId: _currentUserId,
        familyPocketId: pocket.id,
        contributorName: _currentUserName,
        amountKobo: amount * 100,
        currency: 'NGN',
        status: ContributionStatus.recorded,
        origin: ContributionOrigin.devSimulation,
        moneyMovement: false,
        idempotencyKey:
            'local${DateTime.now().microsecondsSinceEpoch.toString()}',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  static int _newestFirst(ContributionRecord first, ContributionRecord second) {
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
}
