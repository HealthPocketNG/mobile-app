import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

import 'auth_v2_widgets.dart';

enum AppPinMode { create, unlock }

class AppPinScreen extends StatefulWidget {
  const AppPinScreen({required this.appState, required this.mode, super.key});
  final AppState appState;
  final AppPinMode mode;
  @override
  State<AppPinScreen> createState() => _AppPinScreenState();
}

class _AppPinScreenState extends State<AppPinScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _firstPin;
  String? _error;
  bool get _creating => widget.mode == AppPinMode.create;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _pin.text.length != 6) {
      setState(() => _error = 'Enter your six-digit PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        if (_firstPin == null) {
          _firstPin = _pin.text;
          _pin.clear();
          return;
        }
        if (_firstPin != _pin.text) {
          _pin.clear();
          setState(() => _error = 'PINs do not match. Try again.');
          return;
        }
        await widget.appState.setPin(_pin.text);
        await widget.appState.completeProfileOnboarding();
      } else {
        final result = await widget.appState.verifyPin(_pin.text);
        if (!result.isValid) {
          if (!mounted) return;
          _pin.clear();
          if (result.isLocked) {
            Navigator.pushReplacementNamed(
              context,
              AppRoute.accountLocked.path,
              arguments: result.lockedUntil,
            );
            return;
          }
          setState(
            () => _error =
                'Incorrect PIN. ${result.remainingAttempts} attempts remaining.',
          );
          return;
        }
      }
      if (!mounted) return;
      if (!_creating) {
        final offer = await widget.appState.biometricUnlockService.shouldOffer(
          widget.appState.authRepository.currentUserId!,
        );
        if (!mounted) return;
        if (offer) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoute.biometrics.path,
            (route) => false,
          );
          return;
        }
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        _creating ? AppRoute.onboardingComplete.path : AppRoute.dashboard.path,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not access secure PIN storage. Try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _digit(String digit) {
    if (_busy || _pin.text.length >= 6) return;
    _pin.text += digit;
    if (_pin.text.length == 6 && !_creating) _submit();
  }

  Future<void> _unlockBiometric() async {
    final uid = widget.appState.authRepository.currentUserId;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = await widget.appState.biometricUnlockService.isEnabled(
        uid,
      );
      if (!enabled) {
        if (mounted) {
          setState(() => _error = 'Enter your PIN first to enable biometrics.');
        }
        return;
      }
      final verified = await widget.appState.biometricUnlockService
          .authenticate(uid);
      if (verified && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoute.dashboard.path,
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Biometric unlock is unavailable. Enter your PIN.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.appState.profileStore.profile.fullName.trim();
    final firstName = fullName.isEmpty
        ? 'back'
        : 'back, ${fullName.split(' ').first}';
    final initials = fullName.isEmpty
        ? 'HP'
        : fullName
              .split(' ')
              .take(2)
              .map((word) => word[0].toUpperCase())
              .join();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                children: [
                  if (_creating) const AuthV2Back(),
                  SizedBox(height: _creating ? 40 : 50),
                  if (_creating)
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AuthV2.pale,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset('${AuthV2.assets}3fc25.svg'),
                    )
                  else
                    Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCDEFEA),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initials,
                        style: AuthV2.heading.copyWith(
                          fontSize: 30,
                          color: AuthV2.teal,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    _creating
                        ? (_firstPin == null
                              ? 'Set your login PIN'
                              : 'Confirm your login PIN')
                        : 'Welcome $firstName',
                    textAlign: TextAlign.center,
                    style: AuthV2.heading,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _creating
                        ? 'Use a 6-digit PIN for quick\nand secure access.'
                        : 'Enter your PIN to continue.',
                    textAlign: TextAlign.center,
                    style: AuthV2.body,
                  ),
                  const SizedBox(height: 32),
                  AuthV2CodeCells(
                    controller: _pin,
                    masked: true,
                    onComplete: _creating ? null : _submit,
                  ),
                  if (_creating) ...[
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF9F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '✓  Keep your account secure\n\n✓  Quick and easy login\n\n✓  You can change this anytime',
                        style: AuthV2.body.copyWith(fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoute.pinRecovery.path,
                      ),
                      child: const Text(
                        'Forgot PIN?',
                        style: TextStyle(color: AuthV2.teal),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.appState.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoute.signIn.path,
                            (route) => false,
                          );
                        }
                      },
                      child: Text(
                        'Not you? Sign in with a different account',
                        style: AuthV2.body.copyWith(
                          fontSize: 12,
                          color: AuthV2.teal,
                        ),
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (!_creating) ...[
                    SizedBox(
                      height: (bounds.maxHeight - 640).clamp(24.0, 180.0),
                    ),
                    SizedBox(
                      height: 264,
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.85,
                        children: [
                          for (final digit in const [
                            '1',
                            '2',
                            '3',
                            '4',
                            '5',
                            '6',
                            '7',
                            '8',
                            '9',
                          ])
                            TextButton(
                              onPressed: () => _digit(digit),
                              child: Text(
                                digit,
                                style: AuthV2.heading.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: _busy ? null : _unlockBiometric,
                            icon: SvgPicture.asset('${AuthV2.assets}0af42.svg'),
                          ),
                          TextButton(
                            onPressed: () => _digit('0'),
                            child: Text(
                              '0',
                              style: AuthV2.heading.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_pin.text.isNotEmpty) {
                                _pin.text = _pin.text.substring(
                                  0,
                                  _pin.text.length - 1,
                                );
                              }
                            },
                            icon: SvgPicture.asset('${AuthV2.assets}c6bdc.svg'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _creating
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: AuthV2Button(
                  label: 'Continue   →',
                  onPressed: _busy ? null : _submit,
                  busy: _busy,
                ),
              ),
            )
          : null,
    );
  }
}
