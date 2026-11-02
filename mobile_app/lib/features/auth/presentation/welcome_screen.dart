import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';

import 'auth_v2_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 64),
            Text(
              'A healthier\ntomorrow, together.',
              textAlign: TextAlign.center,
              style: AuthV2.heading.copyWith(color: const Color(0xFF0E8C86)),
            ),
            const SizedBox(height: 8),
            Text(
              'Save, pay and access quality\nhealthcare all in one place.',
              textAlign: TextAlign.center,
              style: AuthV2.body,
            ),
            const SizedBox(height: 46),
            Image.asset(
              '${AuthV2.assets}2081d.png',
              width: 270,
              height: 210,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            AuthV2Button(
              label: 'Get Started   →',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoute.signUp.path),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoute.signIn.path),
              child: Text(
                'Already have an account? Sign In',
                style: AuthV2.body.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
