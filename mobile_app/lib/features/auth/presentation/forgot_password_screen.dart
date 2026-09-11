import 'package:flutter/material.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/core/data/repository_contracts.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      await widget.authRepository.sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      if (mounted) {
        setState(() => _message = 'Password-reset instructions sent.');
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset your password',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter the email linked to your account and we’ll send reset instructions.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                  ),
                  validator: (value) {
                    if (value == null ||
                        !value.contains('@') ||
                        !value.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_message != null) ...[
                  Text(_message!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppPrimaryButton(
                  label: _isSending ? 'Sending…' : 'Send reset instructions',
                  onPressed: _isSending ? null : _sendResetLink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
