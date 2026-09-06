import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_theme.dart';

class HealthPocketApp extends StatefulWidget {
  const HealthPocketApp({super.key});

  @override
  State<HealthPocketApp> createState() => _HealthPocketAppState();
}

class _HealthPocketAppState extends State<HealthPocketApp> {
  final AppState _appState = AppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, child) => MaterialApp(
        title: 'HealthPocket',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        onGenerateRoute: AppRouter(_appState).onGenerateRoute,
        initialRoute: AppRoute.splash.path,
      ),
    );
  }
}
