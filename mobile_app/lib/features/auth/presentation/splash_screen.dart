import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _startupTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startupTimer = Timer(const Duration(milliseconds: 1200), _resolveSession);
  }

  Future<void> _resolveSession() async {
    try {
      final destination = await widget.appState.resolveStartup();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        appRouteForAuthFlow(destination).path,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'We could not restore your session. Try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            child: Opacity(opacity: 0, child: AppBrandLogo()),
          ),
          const Positioned(top: -55, right: -40, child: _SoftOrb(size: 170)),
          const Positioned(left: -45, top: 190, child: _SoftOrb(size: 125)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/onboarding/HPLogo.png', height: 58),
                const SizedBox(height: 16),
                Text(
                  'People care.\nBrighter days.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                if (_errorMessage == null)
                  SizedBox(
                    width: 96,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: AppColors.primarySoft,
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _resolveSession();
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 38,
            child: Image.asset(
              'assets/onboarding/splashHealthcareCharacters.png',
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
          const Align(alignment: Alignment.bottomCenter, child: _CareCity()),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.primarySoft,
      shape: BoxShape.circle,
    ),
  );
}

class _CareCity extends StatelessWidget {
  const _CareCity();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(height: 54, color: const Color(0xFFB9E9DD)),
          Positioned(
            bottom: 38,
            child: Container(
              width: 112,
              height: 94,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border.all(color: AppColors.outline),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_hospital_rounded,
                    color: AppColors.secondary,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.window, color: AppColors.primary),
                      Icon(Icons.door_front_door, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 38,
            bottom: 42,
            child: Icon(Icons.park_rounded, color: AppColors.primary, size: 60),
          ),
          const Positioned(
            right: 34,
            bottom: 42,
            child: Icon(Icons.park_rounded, color: AppColors.primary, size: 68),
          ),
        ],
      ),
    );
  }
}
