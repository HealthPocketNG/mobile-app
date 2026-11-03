import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/backend/trusted_backend_client.dart';
import 'package:healthpocket/features/dashboard/data/notification_inbox_repository.dart';
import 'package:healthpocket/features/dashboard/presentation/coverage_details_screen.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/dashboard/presentation/notifications_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';

void main() {
  testWidgets('empty dashboard card fits and opens Add Money', (tester) async {
    final savings = SavingsStore();
    final profile = ProfileStore();
    addTearDown(savings.dispose);
    addTearDown(profile.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoute.addMoney.path: (_) =>
                const Scaffold(body: Text('Add Money destination')),
          },
          home: DashboardScreen(
            savingsStore: savings,
            profileStore: profile,
            designPreview: true,
            emptyPreview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No activity yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Add Money').last);
    await tester.pumpAndSettle();
    expect(find.text('Add Money destination'), findsOneWidget);
  });

  testWidgets('estimate explanation opens over coverage list and dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CoverageDetailsScreen(balanceKobo: 1250000)),
    );
    await tester.tap(find.text('Your balance'));
    await tester.pumpAndSettle();
    expect(find.text('How we estimate prices'), findsOneWidget);
    expect(find.text('Based on partner rates'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('How we estimate prices'), findsNothing);
  });

  testWidgets('preview inbox filters, marks read and shows empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationsScreen(designPreview: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('You have 3 new updates.'), findsOneWidget);
    expect(find.text('Savings added'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing new right now.'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications in this filter'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Savings added'), findsOneWidget);
  });

  testWidgets('populated notifications fit a narrow phone', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      const MaterialApp(home: NotificationsScreen(designPreview: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Savings added'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification actions stay on the right at both widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        const MaterialApp(home: NotificationsScreen(designPreview: true)),
      );
      await tester.pumpAndSettle();
      final settings = find.byKey(const Key('notification-settings-action'));
      expect(tester.getTopRight(settings).dx, width - 20);
      expect(tester.getTopLeft(settings).dy, 12);
      expect(
        tester.getTopRight(find.text('Mark all as read')).dx,
        lessThan(tester.getTopLeft(settings).dx),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('notification empty design fits 320px', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpWidget(
      const MaterialApp(
        home: NotificationsScreen(designPreview: true, previewEmpty: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
    expect(
      find.image(
        const AssetImage(
          'assets/dashboard/v2/states/notifications-empty-bell.png',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('real inbox reads and marks through the trusted backend', (
    tester,
  ) async {
    final client = _FakeNotificationClient();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: NotificationInboxRepository(client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.actions.first, TrustedBackendAction.notificationsList);
    expect(find.text('Backend savings update'), findsOneWidget);
    expect(find.text('Mercy contributed'), findsNothing);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(client.actions.last, TrustedBackendAction.notificationsMarkAllRead);
    expect(find.text('Nothing new right now.'), findsOneWidget);
  });

  testWidgets('opening a real notification marks only that item read', (
    tester,
  ) async {
    final client = _FakeNotificationClient();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: NotificationInboxRepository(client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backend savings update'));
    await tester.pumpAndSettle();
    expect(client.actions.last, TrustedBackendAction.notificationsMarkRead);
    expect(client.payloads.last['notificationId'], 'notice-1');
    expect(find.text('Nothing new right now.'), findsOneWidget);
  });
}

class _FakeNotificationClient implements TrustedBackendClient {
  final actions = <TrustedBackendAction>[];
  final payloads = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> call(
    TrustedBackendAction action, {
    Map<String, Object?> payload = const {},
  }) async {
    actions.add(action);
    payloads.add(payload);
    if (action == TrustedBackendAction.notificationsList) {
      return {
        'notifications': [
          {
            'notificationId': 'notice-1',
            'category': 'savings',
            'type': 'savings_updated',
            'title': 'Backend savings update',
            'body': 'A verified savings update.',
            'readState': 'unread',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      };
    }
    return {};
  }
}
