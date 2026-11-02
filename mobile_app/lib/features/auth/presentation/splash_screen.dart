import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/app/app_state.dart';
import 'package:healthpocket/core/logging/backend_logger.dart';

import 'auth_v2_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.appState, super.key});
  final AppState appState;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), _resolve);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final destination = await widget.appState.resolveStartup();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          appRouteForAuthFlow(destination).path,
        );
      }
    } catch (error) {
      BackendLogger.instance.error(
        'auth.session.restore_failed',
        fields: {
          'operation': 'restore_session',
          'entity': 'auth_session',
          'outcome': 'failure',
          'errorType': error.runtimeType.toString(),
        },
      );
      if (mounted &&
          (error is SocketException ||
              (error is FirebaseException &&
                  {
                    'unavailable',
                    'network-request-failed',
                  }.contains(error.code)))) {
        Navigator.pushReplacementNamed(context, AppRoute.offline.path);
        return;
      }
      if (mounted) {
        setState(
          () => _error = 'We could not restore your session. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.appState.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoute.welcome.path,
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We could not reset this session. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: SplashArtwork()),
        if (_error != null)
          Positioned(
            bottom: 42,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _busy ? null : _resolve,
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: _busy ? null : _discard,
                  child: const Text('Sign out and start again'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The same V2 artwork is shown while Firebase initializes and while the
/// authenticated destination is resolved, avoiding a blank startup interval.
class SplashArtwork extends StatelessWidget {
  const SplashArtwork({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final h = constraints.maxHeight;
      return Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE4F6F3), Color(0xFFF6FCFB), Colors.white],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: h * .546,
            left: 32,
            child: const _Orb(color: Color(0xFFE4F6F3)),
          ),
          Positioned(top: h * .546, right: 58, child: const _Orb()),
          Positioned(
            top: h * .2725,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 220,
                  height: 153,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          left: -27.5,
                          top: -56.4,
                          width: 275,
                          height: 275,
                          child: Image.asset(
                            '${AuthV2.assets}748df.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'HEALTHIER TOMORROW, TOGETHER',
                  style: AuthV2.body.copyWith(fontSize: 8, letterSpacing: 2.5),
                ),
              ],
            ),
          ),
          Positioned(
            top: h * .52,
            left: 0,
            right: 0,
            child: Image.asset(
              '${AuthV2.assets}7e4fa.png',
              height: 202,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: h * .142,
            left: 0,
            right: 0,
            child: Text(
              'People Care.\nBrighter days.',
              textAlign: TextAlign.center,
              style: AuthV2.body.copyWith(
                color: const Color(0xFF0E8C86),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _Orb extends StatelessWidget {
  const _Orb({this.color = const Color(0xFFCDEFEA)});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    height: 150,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
