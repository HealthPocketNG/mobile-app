import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

enum AuthMode { signIn, signUp }

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({required this.mode, required this.appState, super.key});

  final AuthMode mode;
  final AppState appState;

  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  bool _acceptedTerms = false;
  bool _isBusy = false;
  String? _errorMessage;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  Future<void> _continueWithGoogle() async {
    if (_isSignUp && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Privacy Policy.'),
        ),
      );
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.appState.authRepository.signInWithGoogle();
      if (result == null) return;
      final destination = await widget.appState.acceptAuthentication(result);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        appRouteForAuthFlow(destination).path,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const Center(
              child: AppBrandLogo(showTagline: true, centered: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AuthSwitcher(isSignUp: _isSignUp),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _isSignUp ? 'Create your account' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Continue securely with your Google account.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            if (_isSignUp) ...[
              const SizedBox(height: AppSpacing.lg),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() => _acceptedTerms = value ?? false);
                },
                title: const Text(
                  'I agree to the Terms of Service and Privacy Policy.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _continueWithGoogle,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
              label: Text(_isBusy ? 'Please wait…' : 'Continue with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthSwitcher extends StatelessWidget {
  const _AuthSwitcher({required this.isSignUp});

  final bool isSignUp;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool selected, AppRoute route) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selected
            ? null
            : () => Navigator.pushReplacementNamed(context, route.path),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          tab('Sign up', isSignUp, AppRoute.signUp),
          tab('Log in', !isSignUp, AppRoute.signIn),
        ],
      ),
    );
  }
}
