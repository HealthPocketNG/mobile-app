import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:healthpocket/core/theme/app_spacing.dart';
import 'package:healthpocket/features/auth/domain/auth_user.dart';

class PinRecoveryScreen extends StatefulWidget {
  const PinRecoveryScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends State<PinRecoveryScreen> {
  bool _isBusy = false;
  String? _message;
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _withGoogle() async {
    await _reauthenticate(() async {
      final completed = await widget.appState.reauthenticateAndResetPin();
      if (!completed) throw const AuthFailure('Google Sign-In was cancelled.');
    });
  }

  Future<void> _withEmail() async {
    await _reauthenticate(() async {
      final completed = await widget.appState
          .reauthenticateAndResetPinWithEmail(_password.text);
      if (!completed) throw const AuthFailure('The password is incorrect.');
    });
  }

  Future<void> _reauthenticate(Future<void> Function() operation) async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await operation();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoute.createPin.path,
        (route) => false,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'We could not reset the local PIN. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesPassword =
        widget.appState.authRepository.currentUser?.usesPassword == true &&
        widget.appState.authRepository.currentUser?.usesGoogle != true;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset app PIN')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Confirm your account',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Re-authenticate to create a new local PIN.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (usesPassword) ...[
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Account password',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _isBusy ? null : _withEmail,
                child: Text(_isBusy ? 'Checking…' : 'Confirm password'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _withGoogle,
                icon: SvgPicture.asset(
                  'assets/auth/v2/google_g.svg',
                  width: 18,
                  height: 18,
                ),
                label: Text(_isBusy ? 'Checking…' : 'Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
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
