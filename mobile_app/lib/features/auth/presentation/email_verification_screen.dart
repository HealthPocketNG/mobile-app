import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isSending = false;
  String? _message;

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    try {
      final destination = await widget.appState.acceptEmailVerification();
      if (!mounted) return;
      if (destination == AuthFlowDestination.verifyEmail) {
        setState(
          () => _message = 'Your email isn’t verified yet. Open the verification link in your email, then try again.',
        );
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        appRouteForAuthFlow(destination).path,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      await widget.appState.authRepository.sendEmailVerification();
      if (mounted) {
        setState(() => _message = 'A new verification email has been sent.');
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    await widget.appState.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoute.welcome.path,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.appState.authRepository.currentUser?.email ??
        'your email address';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Image.asset(
              'assets/onboarding/HP-Onboarding.png',
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Verify your email',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We’ve sent a verification link to\n$email\n\nOpen the link in your email to verify your account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.inkMuted, height: 1.45),
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.primaryDark),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: _isChecking ? 'Checking…' : 'I’ve verified my email',
              onPressed: _isChecking ? null : _checkVerification,
            ),
            TextButton(
              onPressed: _isSending ? null : _resend,
              child: Text(
                _isSending ? 'Sending…' : 'Resend verification email',
              ),
            ),
            TextButton(
              onPressed: _useAnotherAccount,
              child: const Text('Use another account'),
            ),
          ],
        ),
      ),
    );
  }
}
