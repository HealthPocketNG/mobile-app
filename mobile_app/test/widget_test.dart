import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/health_pocket_app.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/presentation/family_pocket_screen.dart';
import 'package:healthpocket/features/savings/application/savings_store.dart';
import 'package:healthpocket/features/savings/presentation/savings_goals_screen.dart';

void main() {
  testWidgets('shows the HealthPocket launch screen', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    expect(find.byType(AppBrandLogo), findsOneWidget);
  });

  testWidgets('moves from launch to account creation', (tester) async {
    await tester.pumpWidget(const HealthPocketApp());

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prepare for medical'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('dashboard shows savings summary and core navigation', (
    tester,
  ) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(savingsStore: store)),
    );

    expect(find.text('Total health savings'), findsOneWidget);
    expect(find.text('₦60,300'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Family Pocket'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('records a mock goal contribution', (tester) async {
    final store = SavingsStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SavingsGoalsScreen(store: store)),
    );

    await tester.tap(find.text('Add savings').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '5000');
    await tester.tap(find.text('Record mock contribution'));
    await tester.pumpAndSettle();

    expect(find.text('₦47,300'), findsOneWidget);
    expect(store.contributions.first.amount, 5000);
    expect(store.contributions.first.goalTitle, 'Family Health Fund');
  });

  testWidgets('invites a Family Pocket member', (tester) async {
    final store = FamilyPocketStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: FamilyPocketScreen(store: store)),
    );

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Tola Adebayo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'tola@example.com',
    );
    await tester.tap(find.text('Send demo invite'));
    await tester.pumpAndSettle();

    expect(find.text('Tola Adebayo'), findsOneWidget);
    expect(store.selectedPocket.members.last.isPending, isTrue);
  });
}
