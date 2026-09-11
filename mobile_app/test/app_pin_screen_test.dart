import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/data/app_pin_repository.dart';
import 'package:healthpocket/features/auth/data/in_memory_auth_repository.dart';
import 'package:healthpocket/features/auth/presentation/app_pin_screen.dart';

void main() {
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

    await auth.signInWithEmail(
      email: 'amara@example.com',
      password: 'secure-password',
    );
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
