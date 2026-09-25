import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

enum AppPinMode { create, unlock }

class AppPinScreen extends StatefulWidget {
  const AppPinScreen({required this.appState, required this.mode, super.key});

  final AppState appState;
  final AppPinMode mode;

  @override
  State<AppPinScreen> createState() => _AppPinScreenState();
}

class _AppPinScreenState extends State<AppPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isBusy = false;
  String? _message;

  bool get _isCreating => widget.mode == AppPinMode.create;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      if (_isCreating) {
        await widget.appState.setPin(_pinController.text);
        await widget.appState.completeProfileOnboarding();
      } else {
        final result = await widget.appState.verifyPin(_pinController.text);
        if (!result.isValid) {
          if (!mounted) return;
          setState(() {
            _pinController.clear();
            _message = result.isLocked
                ? 'Too many attempts. Try again in 30 seconds.'
                : 'Incorrect PIN. ${result.remainingAttempts} attempts remaining.';
          });
          return;
        }
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        _isCreating
            ? AppRoute.onboardingComplete.path
            : AppRoute.dashboard.path,
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
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.xl),
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _isCreating ? 'Set your login PIN' : 'Welcome back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isCreating
                    ? 'Use a 6-digit PIN for quick and secure access.'
                    : 'Enter your six-digit HealthPocket PIN to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              _pinField(
                _pinController,
                '6-digit PIN',
                autoSubmit: !_isCreating,
              ),
              if (_isCreating) ...[
                const SizedBox(height: AppSpacing.md),
                _pinField(
                  _confirmationController,
                  'Confirm PIN',
                  confirmation: true,
                ),
              ],
              if (_isCreating) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A simple, secure sign-in',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Keep your account secure\n• Quick and easy login\n• You can change this anytime',
                      ),
                    ],
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
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: _isBusy
                    ? 'Please wait…'
                    : _isCreating
                    ? 'Continue  →'
                    : 'Unlock',
                onPressed: _isBusy ? null : _submit,
              ),
              if (!_isCreating)
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoute.pinRecovery.path),
                  child: const Text('Forgot PIN?'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _pinField(
    TextEditingController controller,
    String label, {
    bool confirmation = false,
    bool autoSubmit = false,
  }) => TextFormField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: autoSubmit
        ? (value) {
            if (value.length == 6 && !_isBusy) _submit();
          }
        : null,
    decoration: InputDecoration(labelText: label, counterText: ''),
    validator: (value) {
      if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) {
        return 'Enter exactly six digits';
      }
      if (confirmation && value != _pinController.text) {
        return 'PINs do not match';
      }
      return null;
    },
  );
}
