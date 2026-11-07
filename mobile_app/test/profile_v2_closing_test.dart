import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/profile/presentation/profile_v2_closing_pages.dart';
import 'package:healthpocket/features/profile/presentation/profile_screen.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';

void main() {
  testWidgets('security and support entries open the new Profile pages', (
    tester,
  ) async {
    final store = ProfileStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(store: store)));
    await tester.tap(find.text('Account & Security'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active Sessions'));
    await tester.pumpAndSettle();
    expect(find.text('This device'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete account'), 180);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Keep My Account'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
    await tester.tap(find.text('Report an Issue'));
    await tester.pumpAndSettle();
    expect(find.text("What's the issue about?"), findsOneWidget);
  });

  testWidgets('logout sheet requires explicit confirmation', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProfileLogoutSheet(
                  onLogOut: () async {
                    calls++;
                  },
                ),
              ),
              child: const Text('Open logout'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open logout'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of\nHealthPocket?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Open logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets(
    'issue form validates details and opens a draft without claiming delivery',
    (tester) async {
      Uri? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileReportIssueScreen(
            openEmail: (uri) async {
              draft = uri;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      expect(
        find.text('Describe the issue before continuing.'),
        findsOneWidget,
      );
      expect(draft, isNull);
      await tester.enterText(
        find.byType(TextField),
        'The savings page did not load.',
      );
      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      expect(draft?.scheme, 'mailto');
      expect(
        draft?.queryParameters['subject'],
        'HealthPocket issue · Payments',
      );
      expect(
        draft?.queryParameters['body'],
        contains('The savings page did not load.'),
      );
      expect(find.textContaining('Nothing has been submitted'), findsOneWidget);
    },
  );

  testWidgets('delete page opens a request draft and does not claim deletion', (
    tester,
  ) async {
    Uri? draft;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileDeleteAccountScreen(
          openEmail: (uri) async {
            draft = uri;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Continue to Delete'));
    await tester.pump();
    expect(
      draft?.queryParameters['subject'],
      'HealthPocket account deletion request',
    );
    expect(
      find.textContaining('Your account has not been deleted'),
      findsOneWidget,
    );
  });

  testWidgets('session screen lists only this device and fits a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: ProfileActiveSessionsScreen()),
    );
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Chrome on Windows'), findsNothing);
    expect(find.text('iPhone'), findsNothing);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
