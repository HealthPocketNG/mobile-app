import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/features/auth/presentation/auth_v2_widgets.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          Image.asset(
            '${AuthV2.assets}a38b8.png',
            width: 330,
            height: 300,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          const AuthV2Heading(
            "You're all set!",
            'Welcome to HealthPocket.\nTogether, for a healthier\ntomorrow.',
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: AuthV2Button(
              label: 'Go to Dashboard   →',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoute.dashboard.path,
                (route) => false,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
