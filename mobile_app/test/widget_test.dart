import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/health_pocket_app.dart';

void main() {
  testWidgets('shows the HealthPocket launch screen', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    expect(find.text('HealthPocket'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
