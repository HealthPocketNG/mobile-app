import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/core/widgets/app_scroll_behavior.dart';

void main() {
  testWidgets('top-level pages keep breathing room at both scroll edges', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView(
            children: [
              Container(key: const Key('first'), height: 800),
              Container(key: const Key('last'), height: 40),
            ],
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const Key('first'))).dy, 8);
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byKey(const Key('last'))).dy, 584);
  });
}
