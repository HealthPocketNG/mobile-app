import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/widgets/app_bottom_navigation.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';

void main() {
  testWidgets(
    'badge follows actionable invitations and clears on account reset',
    (tester) async {
      final store = FamilyPocketStore();
      addTearDown(store.dispose);
      final invitation = FamilyInvitation(
        id: 'invite',
        pocketId: 'pocket',
        pocketName: 'Family',
        inviteeName: 'Member',
        email: 'member@example.com',
        inviterName: 'Admin',
        canContribute: true,
        isBeneficiary: false,
        status: FamilyInvitationStatus.pending,
        createdBy: 'admin',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      void load(FamilyInvitation invite) => store.hydratePersistent(
        userId: 'member',
        name: 'Member',
        email: 'member@example.com',
        pockets: const [],
        contributions: const [],
        receivedInvitations: [invite],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FamilyInvitationScope(
            store: store,
            child: const Scaffold(
              bottomNavigationBar: AppBottomNavigation(currentIndex: 2),
            ),
          ),
        ),
      );
      bool visible() => tester
          .widgetList<Badge>(find.byType(Badge))
          .any((badge) => badge.isLabelVisible);
      expect(visible(), isFalse);
      load(invitation);
      await tester.pump();
      expect(visible(), isTrue);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '1 pending invitation',
        ),
        findsWidgets,
      );
      for (final status in [
        FamilyInvitationStatus.accepted,
        FamilyInvitationStatus.declined,
        FamilyInvitationStatus.cancelled,
        FamilyInvitationStatus.expired,
      ]) {
        load(invitation.copyWith(status: status));
        await tester.pump();
        expect(visible(), isFalse);
      }
      load(invitation);
      await tester.pump();
      store.resetForNewUser(name: 'Other', email: 'other@example.com');
      await tester.pump();
      expect(visible(), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
