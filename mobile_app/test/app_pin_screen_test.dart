import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/presentation/app_pin_screen.dart';

void main() {
  testWidgets('requires confirmation before creating a six-digit PIN', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = InMemoryAuthRepository();
    final appState = AppState(
      authRepository: auth,
      pinRepository: SecureAppPinRepository(
        storage: MemorySecureValueStore(),
        algorithm: Pbkdf2.hmacSha256(iterations: 10, bits: 256),
      ),
    );
    addTearDown(appState.dispose);
    addTearDown(auth.dispose);
    await auth.signInWithGoogle();

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoute.onboardingComplete.path: (_) =>
              const Scaffold(body: Text('PIN created')),
        },
        home: AppPinScreen(appState: appState, mode: AppPinMode.create),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '482913');
    await tester.enterText(fields.at(1), '482914');
    final continueButton = find.text('Continue  →');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();
    expect(find.text('PINs do not match'), findsOneWidget);

    await tester.enterText(fields.at(1), '482913');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('PIN created'), findsOneWidget);
    expect((await appState.verifyPin('482913')).isValid, isTrue);
  });

  testWidgets('unlocks automatically after the sixth correct PIN digit', (
    tester,
  ) async {
    final auth = InMemoryAuthRepository();
    final appState = AppState(
      authRepository: auth,
      pinRepository: SecureAppPinRepository(
        storage: MemorySecureValueStore(),
        algorithm: Pbkdf2.hmacSha256(iterations: 10, bits: 256),
      ),
    );
    addTearDown(appState.dispose);
    addTearDown(auth.dispose);

    await auth.signInWithGoogle();
    await appState.setPin('482913');

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoute.dashboard.path: (_) =>
              const Scaffold(body: Text('Unlocked dashboard')),
        },
        home: AppPinScreen(appState: appState, mode: AppPinMode.unlock),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '482913');
    await tester.pumpAndSettle();

    expect(find.text('Unlocked dashboard'), findsOneWidget);
  });
}
