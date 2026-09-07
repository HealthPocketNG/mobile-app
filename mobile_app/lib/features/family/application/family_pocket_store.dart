import 'package:flutter/foundation.dart';
import 'package:healthpocket/features/family/data/mock_family_data.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

class FamilyPocketStore extends ChangeNotifier {
  FamilyPocketStore()
    : _pockets = List.of(MockFamilyData.pockets),
      _contributions = List.of(MockFamilyData.contributions),
      _selectedPocketId = MockFamilyData.pockets.first.id;

  final List<FamilyPocket> _pockets;
  final List<FamilyContribution> _contributions;
  String _selectedPocketId;

  List<FamilyPocket> get pockets => List.unmodifiable(_pockets);
  FamilyPocket get selectedPocket =>
      _pockets.firstWhere((pocket) => pocket.id == _selectedPocketId);
  List<FamilyContribution> get selectedContributions => List.unmodifiable(
    _contributions.where((item) => item.pocketId == _selectedPocketId),
  );

  void selectPocket(String pocketId) {
    if (_selectedPocketId == pocketId) return;
    _selectedPocketId = pocketId;
    notifyListeners();
  }

  void createPocket({
    required String name,
    required String beneficiary,
    required int goalAmount,
  }) {
    final id = 'pocket-${DateTime.now().microsecondsSinceEpoch}';
    _pockets.insert(
      0,
      FamilyPocket(
        id: id,
        name: name,
        beneficiary: beneficiary,
        goalAmount: goalAmount,
        currentAmount: 0,
        members: const [
          FamilyMember(
            id: 'current-user',
            name: 'Samson Adebayo',
            email: 'samson@example.com',
            role: FamilyRole.admin,
          ),
        ],
      ),
    );
    _selectedPocketId = id;
    notifyListeners();
  }

  void inviteMember({
    required String name,
    required String email,
    required FamilyRole role,
  }) {
    final index = _pockets.indexWhere(
      (pocket) => pocket.id == _selectedPocketId,
    );
    if (index == -1) return;
    final pocket = _pockets[index];
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
  }

  void recordContribution(int amount) {
    final index = _pockets.indexWhere(
      (pocket) => pocket.id == _selectedPocketId,
    );
    if (index == -1) return;
    final pocket = _pockets[index];
    _pockets[index] = pocket.copyWith(
      currentAmount: pocket.currentAmount + amount,
    );
    _contributions.insert(
      0,
      FamilyContribution(
        id: 'family-contribution-${DateTime.now().microsecondsSinceEpoch}',
        pocketId: pocket.id,
        memberName: 'You',
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
