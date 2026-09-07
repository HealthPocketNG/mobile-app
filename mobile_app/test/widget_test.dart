import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/health_pocket_app.dart';

void main() {
  testWidgets('shows the HealthPocket launch screen', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    expect(find.text('HealthPocket'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('moves from launch to account creation', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Your health deserves a plan.'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });
}
