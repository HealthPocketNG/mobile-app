import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/core/widgets/app_brand_logo.dart';
import 'package:healthpocket/core/widgets/app_primary_button.dart';
import 'package:healthpocket/features/profile/application/profile_store.dart';

enum AuthMode { signIn, signUp }

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({
    required this.mode,
    required this.profileStore,
    required this.onRegistrationStarted,
    super.key,
  });
  final AuthMode mode;
  final ProfileStore profileStore;
  final VoidCallback onRegistrationStarted;

  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _acceptedTerms = false;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_isSignUp && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Privacy Policy.'),
        ),
      );
      return;
    }
    if (_isSignUp) {
      widget.profileStore.beginRegistration(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      widget.onRegistrationStarted();
    }
    Navigator.pushNamed(context, AppRoute.otp.path);
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
                _isSignUp
                    ? 'Join Nigerians building a healthier, more secure tomorrow.'
                    : 'Continue your health savings journey.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isSignUp) ...[
                _field(
                  controller: _nameController,
                  label: 'Full name',
                  hint: 'e.g. Ada Okafor',
                  icon: Icons.person_outline_rounded,
                  capitalization: TextCapitalization.words,
                  validator: (value) =>
                      _required(value, 'Enter your full name'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _field(
                controller: _emailController,
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _email,
              ),
              if (_isSignUp) ...[
                const SizedBox(height: AppSpacing.sm),
                _field(
                  controller: _phoneController,
                  label: 'Phone number',
                  hint: '+234 800 000 0000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      _required(value, 'Enter your phone number'),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 8 characters',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: _password,
              ),
              if (_isSignUp) ...[
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  obscureText: _obscureConfirmation,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      ),
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Passwords do not match'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _field(
                  label: 'Referral code (optional)',
                  hint: 'e.g. HP123',
                  icon: Icons.card_giftcard_outlined,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedTerms,
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setState(() => _acceptedTerms = value ?? false),
                  title: const Text(
                    'I agree to the Terms of Service and Privacy Policy.',
                  ),
                ),
              ] else
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
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: _isSignUp ? 'Continue' : 'Log in',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _field({
    TextEditingController? controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  String? _email(String? value) =>
      value == null || !value.contains('@') || !value.contains('.')
      ? 'Enter a valid email address'
      : null;

  String? _password(String? value) =>
      value == null || value.length < 8 ? 'Use at least 8 characters' : null;
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
