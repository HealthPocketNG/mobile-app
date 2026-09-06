/// Backend implementations are introduced in Month 2. Features depend on
/// contracts like these, never directly on Firebase or a payment provider.
abstract interface class AuthRepository {
  Future<bool> hasActiveSession();
  Future<void> signOut();
}

abstract interface class SavingsRepository {
  Future<void> createGoal();
  Future<void> recordContribution();
}
