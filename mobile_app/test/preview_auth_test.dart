import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/app/health_pocket_app.dart';
import 'package:healthpocket/features/auth/data/preview_auth_repository.dart';
import 'package:healthpocket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:healthpocket/features/activity/presentation/activity_screen.dart';
import 'package:healthpocket/features/care/presentation/find_care_screen.dart';
import 'package:healthpocket/firebase/firebase_bootstrap.dart';

void main() {
  testWidgets('preview form signs in directly to dashboard', (tester) async {
    final auth = PreviewAuthRepository();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      HealthPocketApp(authRepository: auth, previewMode: true),
    );
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.text('Preview HealthPocket'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'preview123');
    await tester.tap(find.textContaining('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.byType(FindCareScreen), findsOneWidget);
  });

  test(
    'local preview signs in and opens protected screens without onboarding',
    () async {
      final auth = PreviewAuthRepository();
      final state = AppState(authRepository: auth, previewMode: true);
      addTearDown(() {
        state.dispose();
        auth.dispose();
      });

      expect(await state.resolveStartup(), AuthFlowDestination.signIn);
      final result = await auth.signInWithEmail(
        email: '  ME@example.com ',
        password: 'preview123',
      );
      expect(
        await state.acceptAuthentication(result),
        AuthFlowDestination.dashboard,
      );
      expect(state.canAccessProtectedFlows, isTrue);
      expect(state.profileStore.profile.email, 'me@example.com');
      expect(state.savingsStore.plan, isNotNull);
      expect(await state.resolveStartup(), AuthFlowDestination.dashboard);

      await state.signOut();
      expect(state.canAccessProtectedFlows, isFalse);
      expect(await state.resolveStartup(), AuthFlowDestination.signIn);
    },
  );

  test('local preview rejects invalid credentials', () async {
    final auth = PreviewAuthRepository();
    addTearDown(auth.dispose);
    expect(
      auth.signInWithEmail(email: 'invalid', password: 'preview123'),
      throwsA(isA<Exception>()),
    );
    expect(
      auth.signInWithEmail(email: 'me@example.com', password: 'short'),
      throwsA(isA<Exception>()),
    );
    expect(auth.currentUser, isNull);
  });

  test('preview flag is restricted to DEV debug builds', () {
    expect(
      FirebaseConfigurationGuard.resolvePreviewMode(
        environment: AppEnvironment.development,
        isReleaseMode: false,
        setting: 'auto',
      ),
      isTrue,
    );
    expect(
      FirebaseConfigurationGuard.resolvePreviewMode(
        environment: AppEnvironment.development,
        isReleaseMode: false,
        setting: 'false',
      ),
      isFalse,
    );
    expect(
      FirebaseConfigurationGuard.resolvePreviewMode(
        environment: AppEnvironment.development,
        isReleaseMode: true,
        setting: 'auto',
      ),
      isFalse,
    );
    expect(
      FirebaseConfigurationGuard.resolvePreviewMode(
        environment: AppEnvironment.production,
        isReleaseMode: true,
        setting: 'auto',
      ),
      isFalse,
    );
    expect(
      () => FirebaseConfigurationGuard.resolvePreviewMode(
        environment: AppEnvironment.production,
        isReleaseMode: true,
        setting: 'true',
      ),
      throwsStateError,
    );
    expect(
      () => FirebaseConfigurationGuard.validatePreviewMode(
        environment: AppEnvironment.development,
        isReleaseMode: false,
        enabled: true,
      ),
      returnsNormally,
    );
    for (final environment in AppEnvironment.values) {
      expect(
        () => FirebaseConfigurationGuard.validatePreviewMode(
          environment: environment,
          isReleaseMode: true,
          enabled: true,
        ),
        throwsStateError,
      );
    }
    expect(
      () => FirebaseConfigurationGuard.validatePreviewMode(
        environment: AppEnvironment.production,
        isReleaseMode: false,
        enabled: true,
      ),
      throwsStateError,
    );
  });
}
