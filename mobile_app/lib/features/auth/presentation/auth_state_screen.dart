import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/features/profile/presentation/support_screen.dart';

import 'auth_v2_widgets.dart';

enum AuthStateKind {
  sessionExpired,
  offline,
  accountLocked,
  biometrics,
  success,
}

class AuthStateScreen extends StatefulWidget {
  const AuthStateScreen({
    required this.kind,
    required this.appState,
    this.lockedUntil,
    super.key,
  });
  final AuthStateKind kind;
  final AppState appState;
  final DateTime? lockedUntil;
  @override
  State<AuthStateScreen> createState() => _AuthStateScreenState();
}

class _AuthStateScreenState extends State<AuthStateScreen> {
  Timer? _timer;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.lockedUntil != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final locked = kind == AuthStateKind.accountLocked;
    final until = widget.lockedUntil;
    final remaining = until?.difference(DateTime.now()) ?? Duration.zero;
    final countdown =
        '${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final title = switch (kind) {
      AuthStateKind.sessionExpired => 'Session expired',
      AuthStateKind.offline => "You're offline",
      AuthStateKind.accountLocked => 'Account temporarily\nlocked',
      AuthStateKind.biometrics => 'Sign in faster',
      AuthStateKind.success => "You're all set!",
    };
    final message = switch (kind) {
      AuthStateKind.sessionExpired => 'For your security, we signed you out after\na period of inactivity.\nSign in again to continue.',
      AuthStateKind.offline =>
        'No internet connection.\nPlease check your network\nand try again.',
      AuthStateKind.accountLocked => 'Too many incorrect PIN attempts. Try again in 15\nminutes, or reset your PIN now.',
      AuthStateKind.biometrics => "Use your fingerprint or face to unlock HealthPocket,\nso you don't have to type your PIN every time.",
      AuthStateKind.success =>
        'Your password has been updated.\nSign in to continue.',
    };
    final primary = switch (kind) {
      AuthStateKind.sessionExpired => 'Sign In',
      AuthStateKind.offline => 'Try Again   ⟳',
      AuthStateKind.accountLocked => 'Reset PIN',
      AuthStateKind.biometrics => 'Enable Fingerprint',
      AuthStateKind.success => 'Continue   →',
    };
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            if (kind == AuthStateKind.offline || kind == AuthStateKind.success)
              Positioned(
                top: 20,
                left: 20,
                child: kind == AuthStateKind.offline
                    ? const AuthV2Back()
                    : IconButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoute.signIn.path,
                          (route) => false,
                        ),
                        icon: const Icon(Icons.close, color: AuthV2.navy),
                      ),
              ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (kind == AuthStateKind.offline)
                      Image.asset(
                        '${AuthV2.assets}c002a.png',
                        width: 160,
                        height: 130,
                        fit: BoxFit.contain,
                      )
                    else if (kind == AuthStateKind.success)
                      SizedBox(
                        width: 180,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SvgPicture.asset('${AuthV2.assets}d4a75.svg'),
                            SvgPicture.asset('${AuthV2.assets}c7288.svg'),
                          ],
                        ),
                      )
                    else
                      AuthV2Emblem(
                        asset: switch (kind) {
                          AuthStateKind.sessionExpired => 'e7bb7.svg',
                          AuthStateKind.accountLocked => '7fbde.svg',
                          AuthStateKind.biometrics => '169e7.svg',
                          _ => 'e7bb7.svg',
                        },
                        background: locked
                            ? const Color(0xFFFFEBC8)
                            : AuthV2.pale,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AuthV2.heading,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AuthV2.body,
                    ),
                    if (locked && remaining > Duration.zero) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBC8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '◷  Try again in $countdown',
                          style: AuthV2.body.copyWith(
                            color: const Color(0xFF9A6000),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (kind == AuthStateKind.biometrics) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AuthV2.pale,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ⓘ  You can change this anytime in Login & PIN.',
                          style: AuthV2.body.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthV2Button(
                label: primary,
                onPressed: _busy ? null : () => _primary(kind),
                busy: _busy,
              ),
              if (kind == AuthStateKind.offline ||
                  locked ||
                  kind == AuthStateKind.biometrics) ...[
                const SizedBox(height: 12),
                AuthV2Button(
                  label: kind == AuthStateKind.offline
                      ? 'Go Back'
                      : locked
                      ? 'Contact Support'
                      : 'Not now',
                  secondary: true,
                  onPressed: _busy ? null : () => _secondary(kind),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _primary(AuthStateKind kind) async {
    switch (kind) {
      case AuthStateKind.sessionExpired:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoute.signIn.path,
          (route) => false,
        );
      case AuthStateKind.offline:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoute.splash.path,
          (route) => false,
        );
      case AuthStateKind.accountLocked:
        Navigator.pushNamed(context, AppRoute.pinRecovery.path);
      case AuthStateKind.biometrics:
        final uid = widget.appState.authRepository.currentUserId;
        if (uid == null) return;
        setState(() {
          _busy = true;
          _error = null;
        });
        try {
          final enabled = await widget.appState.biometricUnlockService.enable(
            uid,
          );
          if (!mounted) return;
          if (enabled) {
            widget.appState.profileStore.setBiometricUnlock(true);
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoute.dashboard.path,
              (route) => false,
            );
          } else {
            setState(
              () => _error =
                  'Biometric setup was not completed. You can use your PIN.',
            );
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Biometrics are unavailable on this device. Use your PIN.',
            );
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      case AuthStateKind.success:
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoute.signIn.path,
          (route) => false,
        );
    }
  }

  Future<void> _secondary(AuthStateKind kind) async {
    switch (kind) {
      case AuthStateKind.offline:
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoute.welcome.path,
            (route) => false,
          );
        }
      case AuthStateKind.accountLocked:
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
        );
      case AuthStateKind.biometrics:
        final uid = widget.appState.authRepository.currentUserId;
        if (uid != null) {
          await widget.appState.biometricUnlockService.decline(uid);
        }
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoute.dashboard.path,
            (route) => false,
          );
        }
      default:
        break;
    }
  }
}
