import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoute.welcome.path);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(top: -55, right: -40, child: _SoftOrb(size: 170)),
          const Positioned(left: -45, top: 190, child: _SoftOrb(size: 125)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBrandLogo(centered: true, showTagline: true),
                const SizedBox(height: 18),
                SizedBox(
                  width: 96,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
              ],
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
