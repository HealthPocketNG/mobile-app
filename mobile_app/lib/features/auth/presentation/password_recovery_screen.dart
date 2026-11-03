import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_v2_widgets.dart';

enum PasswordRecoveryStep { request, sent, create }

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    required this.appState,
    required this.step,
    this.resetCode,
    this.email,
    super.key,
  });
  final AppState appState;
  final PasswordRecoveryStep step;
  final String? resetCode;
  final String? email;
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int _resendSeconds = 45;
  bool get _validPassword =>
      _password.text.length >= 8 &&
      RegExp(r'[0-9]').hasMatch(_password.text) &&
      RegExp(r'[A-Z]').hasMatch(_password.text) &&
      _password.text == _confirmation.text;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email ?? '';
    _password.addListener(_redraw);
    _confirmation.addListener(_redraw);
    if (widget.step == PasswordRecoveryStep.sent) _startCooldown();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _startCooldown() {
    _resendSeconds = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.appState.authRepository.sendPasswordResetEmail(
        _email.text.trim(),
      );
      if (mounted) {
        if (widget.step == PasswordRecoveryStep.sent) {
          _startCooldown();
        } else {
          Navigator.pushNamed(
            context,
            AppRoute.passwordResetSent.path,
            arguments: _email.text.trim(),
          );
        }
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update() async {
    if (_busy) return;
    if (!_validPassword) {
      setState(
        () => _error = 'Meet all password requirements before continuing.',
      );
      return;
    }
    final code = widget.resetCode;
    if (code == null || code.isEmpty) {
      setState(
        () => _error =
            'Open the password reset link from your email to continue.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.appState.authRepository.confirmPasswordReset(
        code: code,
        password: _password.text,
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoute.success.path,
          (route) => false,
        );
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmail() async {
    try {
      final opened = await const MethodChannel('healthpocket/email_app')
          .invokeMethod<bool>('openInbox');
      if (opened == true) return;
    } catch (_) {
      /* Use a browser inbox fallback on other platforms. */
    }
    final opened = await launchUrl(
      Uri.parse('https://mail.google.com/mail/u/0/#inbox'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(
        () => _error = 'Open your email app and find the reset message.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.step == PasswordRecoveryStep.request;
    final sent = widget.step == PasswordRecoveryStep.sent;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          children: [
            const AuthV2Back(),
            SizedBox(height: sent ? 100 : 36),
            if (request) ...[
              const AuthV2Emblem(asset: 'bf87b.svg'),
              const SizedBox(height: 26),
              const AuthV2Heading(
                'Forgot your password?',
                "Enter your email and we'll send you\na link to reset it.",
              ),
              const SizedBox(height: 42),
              AuthV2Field(
                label: 'Email address',
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ] else if (sent) ...[
              const AuthV2Emblem(asset: '6fc57.svg'),
              const SizedBox(height: 26),
              AuthV2Heading(
                'Check your email',
                "We've sent a password reset link to\n${_email.text}.\nThe link expires in 30 minutes.",
              ),
            ] else ...[
              const AuthV2Heading(
                'Create a new password',
                "Choose a strong password you haven't\nused before.",
              ),
              const SizedBox(height: 34),
              AuthV2Field(
                label: 'New password',
                controller: _password,
                password: true,
                hint: '••••••••••',
              ),
              const SizedBox(height: 18),
              AuthV2Field(
                label: 'Confirm password',
                controller: _confirmation,
                password: true,
                hint: 'Re-enter your password',
              ),
              const SizedBox(height: 20),
              _requirement('At least 8 characters', _password.text.length >= 8),
              _requirement(
                'Includes a number',
                RegExp(r'[0-9]').hasMatch(_password.text),
              ),
              _requirement(
                'Includes an uppercase letter',
                RegExp(r'[A-Z]').hasMatch(_password.text),
              ),
              _requirement(
                'Passwords match',
                _confirmation.text.isNotEmpty &&
                    _password.text == _confirmation.text,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthV2Button(
                label: request
                    ? 'Send Reset Link   →'
                    : sent
                    ? 'Open Email App'
                    : 'Update Password   →',
                onPressed: _busy
                    ? null
                    : request
                    ? _send
                    : sent
                    ? _openEmail
                    : _validPassword
                    ? _update
                    : null,
                busy: _busy,
              ),
              if (sent) ...[
                const SizedBox(height: 12),
                AuthV2Button(
                  label: _resendSeconds > 0
                      ? 'Resend link (0:${_resendSeconds.toString().padLeft(2, '0')})'
                      : 'Resend link',
                  secondary: true,
                  onPressed: _busy || _resendSeconds > 0 ? null : _send,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _requirement(String label, bool met) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      '${met ? '●' : '○'}  $label',
      style: AuthV2.body.copyWith(
        fontSize: 12,
        color: met ? const Color(0xFF27A771) : AuthV2.muted,
      ),
    ),
  );
}
