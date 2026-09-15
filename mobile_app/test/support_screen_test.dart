import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';

void main() {
  test('support email contains only a generic feedback template', () {
    final uri = supportEmailUri();
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'gethealthpocket@gmail.com');
    expect(
      uri.queryParameters['subject'],
      'HealthPocket beta feedback / support',
    );
    expect(uri.queryParameters['body'], contains('What happened?'));
    expect(uri.query, contains('%20'));
  });
  for (final outcome in ['opened', 'unavailable', 'exception']) {
    testWidgets('support handles $outcome without claiming delivery', (
      tester,
    ) async {
      Uri? requested;
      await tester.pumpWidget(
        MaterialApp(
          home: SupportScreen(
            openEmail: (uri) async {
              requested = uri;
              if (outcome == 'exception') throw StateError('No handler');
              return outcome == 'opened';
            },
          ),
        ),
      );
      await tester.tap(find.text('Open email app'));
      await tester.pumpAndSettle();
      expect(requested?.path, supportEmail);
      expect(
        find.textContaining(
          outcome == 'opened'
              ? 'Nothing has been sent'
              : 'Could not open an email app',
        ),
        findsOneWidget,
      );
      expect(find.text('Copy email address'), findsOneWidget);
    });
  }
}
