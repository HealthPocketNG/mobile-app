import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_theme.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/core/backend/trusted_backend_client.dart';
import 'package:healthpocket/features/care/domain/care_provider.dart';

class HealthPocketApp extends StatefulWidget {
  const HealthPocketApp({
    super.key,
    this.authRepository,
    this.pinRepository,
    this.profileRepository,
    this.profilePhotoRepository,
    this.savingsRepository,
    this.contributionRepository,
    this.familyPocketRepository,
    this.careDirectoryRepository,
    this.backendClient,
    this.developmentContributionsEnabled = false,
  });

  final AuthRepository? authRepository;
  final AppPinRepository? pinRepository;
  final ProfileRepository? profileRepository;
  final ProfilePhotoRepository? profilePhotoRepository;
  final SavingsRepository? savingsRepository;
  final ContributionRepository? contributionRepository;
  final FamilyPocketRepository? familyPocketRepository;
  final CareDirectoryRepository? careDirectoryRepository;
  final TrustedBackendClient? backendClient;
  final bool developmentContributionsEnabled;

  @override
  State<HealthPocketApp> createState() => _HealthPocketAppState();
}

class _HealthPocketAppState extends State<HealthPocketApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState(
      authRepository: widget.authRepository,
      pinRepository: widget.pinRepository,
      profileRepository: widget.profileRepository,
      profilePhotoRepository: widget.profilePhotoRepository,
      savingsRepository: widget.savingsRepository,
      contributionRepository: widget.contributionRepository,
      familyPocketRepository: widget.familyPocketRepository,
      careDirectoryRepository: widget.careDirectoryRepository,
      backendClient: widget.backendClient,
      developmentContributionsEnabled: widget.developmentContributionsEnabled,
    );
  }

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
