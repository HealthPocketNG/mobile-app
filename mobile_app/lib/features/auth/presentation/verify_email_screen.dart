import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';
import 'package:healthpocket/features/auth/domain/email_verification_service.dart';

import 'auth_v2_widgets.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({required this.appState, super.key});
  final AppState appState;
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  EmailVerificationChallenge? _challenge;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  int get _resendSeconds => _challenge == null
      ? 0
      : _challenge!.resendAvailableAt
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 45);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _request());
  }

  @override
  void dispose() {
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _request() async {
    final user = widget.appState.authRepository.currentUser;
    final service = widget.appState.emailVerificationService;
    if (user == null || service == null) {
      setState(() => _error = 'Email verification is unavailable.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await service.requestChallenge(
        authenticatedUserId: user.uid,
      );
      if (mounted) {
        setState(() => _challenge = challenge);
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _resendSeconds == 0) {
            timer.cancel();
            return;
          }
          setState(() {});
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not send a code. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the six-digit code.');
      return;
    }
    final user = widget.appState.authRepository.currentUser;
    final service = widget.appState.emailVerificationService;
    if (user == null || service == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await service.verifyChallenge(
        authenticatedUserId: user.uid,
        challengeId: _challenge?.challengeId ?? user.uid,
        code: _code.text,
      );
      if (outcome != EmailVerificationOutcome.verified) {
        setState(() => _error = 'That code is invalid or has expired.');
        return;
      }
      final destination = await widget.appState.acceptEmailVerification();
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
        setState(() => _error = 'Could not verify your code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.appState.authRepository.currentUser?.email ?? 'your email';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              AuthV2Back(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoute.signUp.path,
                  (route) => false,
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 150,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 8,
                      child: SvgPicture.asset('${AuthV2.assets}7dbc4.svg'),
                    ),
                    Positioned(
                      top: 12,
                      child: SvgPicture.asset('${AuthV2.assets}1a094.svg'),
                    ),
                    Positioned(
                      top: 22,
                      child: SvgPicture.asset('${AuthV2.assets}3c02d.svg'),
                    ),
                    Positioned(
                      bottom: 8,
                      child: SvgPicture.asset('${AuthV2.assets}5f0c8.svg'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Verify your email', style: AuthV2.heading),
              const SizedBox(height: 34),
              Text(
                "We've sent a 6-digit code to",
                style: AuthV2.body,
                textAlign: TextAlign.center,
              ),
              Text(
                email,
                style: AuthV2.body.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              AuthV2CodeCells(controller: _code, onComplete: _verify),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _busy || _resendSeconds > 0 ? null : _request,
                child: Text(
                  "Didn't receive the code? Resend${_resendSeconds > 0 ? ' (0:${_resendSeconds.toString().padLeft(2, '0')})' : ''}",
                  style: AuthV2.body.copyWith(fontSize: 12, color: AuthV2.teal),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: AuthV2Button(
            label: 'Continue   →',
            onPressed: _busy ? null : _verify,
            busy: _busy,
          ),
        ),
      ),
    );
  }
}
