import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/family/data/mock_family_data.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

class FamilyPocketStore extends ChangeNotifier {
  FamilyPocketStore()
    : _pockets = List.of(MockFamilyData.pockets),
      _contributions = List.of(MockFamilyData.contributions),
      _selectedPocketId = MockFamilyData.pockets.first.id;

  static const currentUserId = 'current-user';

  final List<FamilyPocket> _pockets;
  final List<FamilyContribution> _contributions;
  String? _selectedPocketId;
  String _currentUserName = 'Samson Adebayo';
  String _currentUserEmail = 'samson@example.com';

  List<FamilyPocket> get pockets => List.unmodifiable(_pockets);
  FamilyPocket? get selectedPocket {
    final pocketId = _selectedPocketId;
    if (pocketId == null) return null;
    return _pockets.where((pocket) => pocket.id == pocketId).firstOrNull;
  }

  List<FamilyContribution> get selectedContributions {
    final pocketId = _selectedPocketId;
    if (pocketId == null) return const [];
    return List.unmodifiable(
      _contributions.where((item) => item.pocketId == pocketId),
    );
  }

  int get selectedBalance => selectedContributions
      .where(
        (contribution) =>
            contribution.status == FamilyContributionStatus.completed,
      )
      .fold(0, (total, contribution) => total + contribution.amount);

  bool get canManageMembers =>
      selectedPocket?.members.any(
        (member) =>
            member.id == currentUserId && member.role == FamilyRole.admin,
      ) ??
      false;

  void resetForNewUser({required String name, required String email}) {
    _currentUserName = name;
    _currentUserEmail = email;
    _pockets.clear();
    _contributions.clear();
    _selectedPocketId = null;
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

  void createPocket({required String name, required String beneficiary}) {
    final id = 'pocket-${DateTime.now().microsecondsSinceEpoch}';
    _pockets.insert(
      0,
      FamilyPocket(
        id: id,
        name: name,
        beneficiary: beneficiary,
        members: [
          FamilyMember(
            id: currentUserId,
            name: _currentUserName,
            email: _currentUserEmail,
            role: FamilyRole.admin,
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
    required FamilyRole role,
  }) {
    final pocket = selectedPocket;
    if (pocket == null || !canManageMembers) return false;
    final index = _pockets.indexWhere((item) => item.id == pocket.id);
    _pockets[index] = pocket.copyWith(
      members: [
        ...pocket.members,
        FamilyMember(
          id: 'member-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          email: email,
          role: role,
          isPending: true,
        ),
      ],
    );
    notifyListeners();
    return true;
  }

  bool removeContributor(String memberId) {
    final pocket = selectedPocket;
    if (pocket == null || !canManageMembers) return false;
    final member = pocket.members
        .where((item) => item.id == memberId)
        .firstOrNull;
    if (member == null ||
        member.id == currentUserId ||
        member.role != FamilyRole.contributor) {
      return false;
    }
    final index = _pockets.indexWhere((item) => item.id == pocket.id);
    _pockets[index] = pocket.copyWith(
      members: pocket.members.where((item) => item.id != memberId).toList(),
    );
    notifyListeners();
    return true;
  }

  void recordContribution(int amount) {
    final pocket = selectedPocket;
    if (pocket == null) return;
    _contributions.insert(
      0,
      FamilyContribution(
        id: 'family-contribution-${DateTime.now().microsecondsSinceEpoch}',
        pocketId: pocket.id,
        memberName: _currentUserName,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
