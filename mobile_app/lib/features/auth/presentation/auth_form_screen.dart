import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

import 'auth_v2_widgets.dart';

enum AuthMode { signIn, signUp }

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({required this.mode, required this.appState, super.key});
  final AuthMode mode;
  final AppState appState;
  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  bool _terms = false;
  bool _busy = false;
  String? _error;
  bool get _signUp =>
      widget.mode == AuthMode.signUp && !widget.appState.previewMode;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AuthResult?> Function() operation) async {
    if (_signUp && !_terms) {
      setState(
        () => _error = 'Please accept the Terms of Service and Privacy Policy.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await operation();
      if (result == null) return;
      final destination = await widget.appState.acceptAuthentication(result);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        appRouteForAuthFlow(destination).path,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not connect. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitEmail() {
    if (!_form.currentState!.validate()) return;
    _run(
      () => _signUp
          ? widget.appState.authRepository.createAccountWithEmail(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : widget.appState.authRepository.signInWithEmail(
              email: _email.text.trim(),
              password: _password.text,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          children: [
            const AuthV2Back(),
            const SizedBox(height: 18),
            AuthV2Heading(
              _signUp
                  ? 'Create your account'
                  : widget.appState.previewMode
                  ? 'Preview HealthPocket'
                  : 'Welcome back',
              widget.appState.previewMode
                  ? 'Use any email and a password of at least 8 characters. This is a local preview.'
                  : _signUp
                  ? 'Join thousands of people building\na healthier tomorrow.'
                  : 'Sign in to keep saving for a\nhealthier tomorrow.',
            ),
            const SizedBox(height: 30),
            if (!widget.appState.previewMode)
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          widget.appState.authRepository.signInWithGoogle,
                        ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AuthV2.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        '${AuthV2.assets}google_g.svg',
                        key: const Key('google-logo'),
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AuthV2.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_signUp) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _emailFocus.requestFocus(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F3F5),
                    foregroundColor: AuthV2.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text(
                    'Continue with Email',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                  ),
                ),
              ),
            ],
            if (!widget.appState.previewMode) const SizedBox(height: 20),
            if (!widget.appState.previewMode)
              Row(
                children: [
                  const Expanded(child: Divider(color: AuthV2.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: AuthV2.body),
                  ),
                  const Expanded(child: Divider(color: AuthV2.border)),
                ],
              ),
            const SizedBox(height: 18),
            if (_signUp) ...[
              AuthV2Field(
                label: 'Full name',
                controller: _name,
                hint: 'David Okafor',
                validator: (v) => v == null || v.trim().length < 2
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            AuthV2Field(
              label: 'Email address',
              controller: _email,
              focusNode: _emailFocus,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 16),
            AuthV2Field(
              label: _signUp ? 'Create a password' : 'Password',
              controller: _password,
              hint: '••••••••••',
              password: true,
              validator: (v) => v == null || v.length < 8
                  ? 'Use at least 8 characters'
                  : null,
            ),
            if (_signUp) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _terms,
                      activeColor: AuthV2.teal,
                      onChanged: (v) => setState(() => _terms = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'I agree to the Terms of Service and Privacy Policy',
                      style: AuthV2.body.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ] else if (!widget.appState.previewMode)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoute.forgotPassword.path,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AuthV2.teal,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthV2Button(
              label: _signUp ? 'Create Account   →' : 'Sign In   →',
              onPressed: _busy ? null : _submitEmail,
              busy: _busy,
            ),
            if (!widget.appState.previewMode) const SizedBox(height: 20),
            if (!widget.appState.previewMode)
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  _signUp ? AppRoute.signIn.path : AppRoute.signUp.path,
                ),
                child: Text(
                  _signUp
                      ? 'Already have an account? Sign In'
                      : 'New to HealthPocket? Create account',
                  style: AuthV2.body.copyWith(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
