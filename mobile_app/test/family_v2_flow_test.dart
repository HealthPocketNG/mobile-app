import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/data/mock_family_data.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';

void main() {
  testWidgets('Family Pocket overview and creation fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Start a new Pocket'));
    await tester.pumpAndSettle();
    expect(find.text('Create Family Pocket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a pocket with the V2 fields and completes the flow', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store, designPreview: true)),
    );

    await tester.tap(find.text('Start a new Pocket'));
    await tester.pumpAndSettle();
    expect(find.text('Create Family Pocket'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'The Ayo Family');
    await tester.enterText(find.byType(TextFormField).at(1), 'Family care');
    await tester.scrollUntilVisible(
      find.text('Default Amount'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(find.byType(TextFormField).last, '750');
    await tester.tap(find.text('Create Pocket'));
    await tester.pumpAndSettle();

    final pocket = store.selectedPocket!;
    expect(pocket.name, 'The Ayo Family');
    expect(pocket.description, 'Family care');
    expect(pocket.frequency, FamilyContributionFrequency.weekly);
    expect(pocket.defaultContributionAmountKobo, 75000);
    expect(find.text('Invite people you trust'), findsOneWidget);

    await tester.tap(find.text('Invite with a Link Instead'));
    await tester.pumpAndSettle();
    expect(find.text('Invite Members'), findsOneWidget);
    expect(find.text('Mercy'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Family Pocket Created!'), findsOneWidget);
    await tester.ensureVisible(find.text('Go to Pocket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Pocket'));
    await tester.pumpAndSettle();
    expect(find.text('The Ayo Family'), findsWidgets);
    expect(find.byTooltip('Back to pockets'), findsOneWidget);
  });

  testWidgets('sample contact invite requires a real email before recording', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store, designPreview: true)),
    );
    await tester.tap(find.text('Start a new Pocket'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'New pocket');
    await tester.tap(find.text('Create Pocket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow Contacts'));
    await tester.pumpAndSettle();

    expect(store.selectedPocket!.invitations, isEmpty);
    await tester.tap(find.text('Invite').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'mercy@example.com',
    );
    await tester.tap(find.text('Record invitation'));
    await tester.pumpAndSettle();
    expect(store.selectedPocket!.invitations, hasLength(1));
    expect(store.selectedPocket!.invitations.single.inviteeName, 'Mercy');
  });

  testWidgets('pocket details lead to V2 management and member role sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );

    await tester.tap(find.text('Adebayo Family Care'));
    await tester.pumpAndSettle();
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Manage pocket'), findsOneWidget);
    expect(find.text('Pocket notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Pocket name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Adebayo Care');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.selectedPocket!.name, 'Adebayo Care');

    await tester.tap(find.text('Members and roles'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Members ('), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('family-member-grace')));
    await tester.pumpAndSettle();
    expect(find.text('Change role'), findsOneWidget);
    expect(find.text('Guardrail'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Beneficiary').last);
    await tester.tap(find.text('Save Role'));
    await tester.pumpAndSettle();
    expect(
      find.text('Role changes are not available in this build yet.'),
      findsOneWidget,
    );
    expect(
      store.selectedPocket!.members
          .firstWhere((member) => member.id == 'grace')
          .role,
      FamilyRole.member,
    );
  });

  testWidgets('member can confirm leaving a pocket and return to overview', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    store.hydratePersistent(
      userId: 'grace',
      name: 'Grace Adebayo',
      email: 'grace@example.com',
      pockets: MockFamilyData.pockets,
      contributions: MockFamilyData.contributions,
    );
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );

    await tester.tap(find.text('Adebayo Family Care'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leave pocket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave pocket'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Adebayo Family Care?'), findsOneWidget);
    await tester.tap(find.text('Leave Pocket'));
    await tester.pumpAndSettle();

    expect(store.pockets, isEmpty);
    expect(find.text('Start a new Pocket'), findsOneWidget);
    expect(find.text('Pocket unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invites tab opens a pending invitation and declines it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    store.hydratePersistent(
      userId: 'invitee',
      name: 'Invitee',
      email: 'invitee@example.com',
      pockets: const [],
      contributions: const [],
      receivedInvitations: [
        FamilyInvitation(
          id: 'invite-1',
          pocketId: 'ayo-pocket',
          pocketName: 'The Ayo Family',
          inviteeName: 'Invitee',
          email: 'invitee@example.com',
          inviterName: 'Daniel O.',
          canContribute: true,
          isBeneficiary: false,
          status: FamilyInvitationStatus.pending,
          createdBy: 'daniel',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          expiresAt: DateTime.now().add(const Duration(days: 5)),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );

    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Daniel O. invited you · 2 days ago'), findsOneWidget);
    await tester.tap(find.text('The Ayo Family'));
    await tester.pumpAndSettle();
    expect(find.text("You're invited!"), findsOneWidget);
    expect(find.text('Join Family Pocket'), findsOneWidget);
    expect(find.text('Weekly · ₦500'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(store.receivedInvitations, isEmpty);
    expect(find.text('No pending invites'), findsOneWidget);
  });

  testWidgets('share invite sheet exposes no fictitious working link', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store, designPreview: true)),
    );
    await tester.tap(find.text('Start a new Pocket'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ayo Family');
    await tester.tap(find.text('Create Pocket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow Contacts'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share Invite Link'));
    await tester.pumpAndSettle();
    expect(find.text('Share invite link'), findsOneWidget);
    expect(find.text('No invite link available'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('healthpocket.app/join/AYO-4F7K'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Share invite link'), findsNothing);
  });

  testWidgets('joining from invitation detail records membership', (
    tester,
  ) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    store.hydratePersistent(
      userId: 'invitee',
      name: 'Invitee',
      email: 'invitee@example.com',
      pockets: MockFamilyData.pockets,
      contributions: const [],
      receivedInvitations: [
        FamilyInvitation(
          id: 'invite-join',
          pocketId: 'adebayo-family-care',
          pocketName: 'Adebayo Family Care',
          inviteeName: 'Invitee',
          email: 'invitee@example.com',
          inviterName: 'Samson Adebayo',
          canContribute: true,
          isBeneficiary: false,
          status: FamilyInvitationStatus.pending,
          createdBy: 'current-user',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 5)),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );
    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adebayo Family Care'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Family Pocket'));
    await tester.pumpAndSettle();

    expect(store.receivedInvitations, isEmpty);
    expect(
      store.selectedPocket!.members.any((member) => member.id == 'invitee'),
      isTrue,
    );
    expect(find.text('My Pockets'), findsOneWidget);
    expect(find.text("You're invited!"), findsNothing);
  });
}
