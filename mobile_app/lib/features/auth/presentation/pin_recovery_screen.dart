import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

class PinRecoveryScreen extends StatefulWidget {
  const PinRecoveryScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends State<PinRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _withPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await _reauthenticate(
      () => widget.appState.authRepository.reauthenticateWithPassword(
        _passwordController.text,
      ),
    );
  }

  Future<void> _withGoogle() async {
    await _reauthenticate(() async {
      final completed = await widget.appState.authRepository
          .reauthenticateWithGoogle();
      if (!completed) throw const AuthFailure('Google Sign-In was cancelled.');
    });
  }

  Future<void> _reauthenticate(Future<void> Function() operation) async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await operation();
      await widget.appState.resetPinAfterReauthentication();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoute.createPin.path,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.authRepository.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset app PIN')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Confirm your Firebase account',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Your app PIN cannot recover or replace your account credential. Re-authenticate to create a new local PIN.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (user?.usesPassword == true)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Account password',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your account password'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(
                      label: _isBusy ? 'Checking…' : 'Confirm password',
                      onPressed: _isBusy ? null : _withPassword,
                    ),
                  ],
                ),
              ),
            if (user?.usesGoogle == true) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _withGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _message!,
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
