import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';

enum AuthMode { signIn, signUp }

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({required this.mode, super.key});

  final AuthMode mode;

  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pushNamed(context, AppRoute.otp.path);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? 'Create your account' : 'Welcome back';
    final subtitle = _isSignUp
        ? 'Start building your healthcare fund today.'
        : 'Sign in to continue your health savings journey.';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_isSignUp) ...[
                TextFormField(
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'e.g. Ada Okafor',
                  ),
                  validator: (value) => _required(value, 'Enter your full name'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                ),
                validator: _email,
              ),
              if (_isSignUp) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '080 0000 0000',
                  ),
                  validator: (value) => _required(value, 'Enter your phone number'),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 8 characters',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: _password,
              ),
              if (!_isSignUp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoute.forgotPassword.path,
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: _isSignUp ? 'Continue' : 'Sign in',
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    _isSignUp ? AppRoute.signIn.path : AppRoute.signUp.path,
                  ),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : 'New to HealthPocket? Create an account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  String? _email(String? value) {
    if (value == null || !value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _password(String? value) {
    if (value == null || value.length < 8) {
      return 'Use at least 8 characters';
    }
    return null;
  }
}
