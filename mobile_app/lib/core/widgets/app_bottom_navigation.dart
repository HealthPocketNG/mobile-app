import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.currentIndex, super.key});

  final int currentIndex;

  static const _assetRoot = 'assets/dashboard/v2/';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EDF0))),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF0B7F7A)
                  : const Color(0xFF5B6477),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          height: 84,
          backgroundColor: AppColors.surface,
          elevation: 0,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? const Color(0xFF0B7F7A)
                  : const Color(0xFF5B6477),
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
          ),
          onDestinationSelected: (index) {
            if (index == currentIndex) return;
            final route = switch (index) {
              0 => AppRoute.dashboard,
              1 => AppRoute.savings,
              2 => AppRoute.findCare,
              3 => AppRoute.activity,
              4 => AppRoute.profile,
              _ => null,
            };
            if (route == null) return;
            Navigator.pushReplacementNamed(context, route.path);
          },
          destinations: [
            NavigationDestination(
              icon: _navIcon('nav-home.svg', false),
              selectedIcon: _navIcon('nav-home.svg', true),
              label: 'Home',
            ),
            NavigationDestination(
              icon: _navIcon('nav-savings.svg', false),
              selectedIcon: _navIcon('nav-savings.svg', true),
              label: 'Savings',
            ),
            NavigationDestination(
              icon: _navIcon('nav-pay.svg', false),
              selectedIcon: _navIcon('nav-pay.svg', true),
              label: 'Pay',
            ),
            NavigationDestination(
              icon: _navIcon('nav-activity.svg', false),
              selectedIcon: _navIcon('nav-activity.svg', true),
              label: 'Activity',
            ),
            const NavigationDestination(
              icon: _FamilyInviteIcon(selected: false),
              selectedIcon: _FamilyInviteIcon(selected: true),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _navIcon(String file, bool selected) => SvgPicture.asset(
    '$_assetRoot$file',
    width: 30,
    height: 30,
    colorFilter: ColorFilter.mode(
      selected ? const Color(0xFF0B7F7A) : const Color(0xFF5B6477),
      BlendMode.srcIn,
    ),
  );
}

class FamilyInvitationScope extends InheritedNotifier<FamilyPocketStore> {
  const FamilyInvitationScope({
    required FamilyPocketStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);
}

class _FamilyInviteIcon extends StatefulWidget {
  const _FamilyInviteIcon({required this.selected});

  final bool selected;

  @override
  State<_FamilyInviteIcon> createState() => _FamilyInviteIconState();
}

class _FamilyInviteIconState extends State<_FamilyInviteIcon> {
  Timer? _expiryTimer;

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context
        .dependOnInheritedWidgetOfExactType<FamilyInvitationScope>()
        ?.notifier;
    final now = DateTime.now();
    final pending =
        store?.receivedInvitations
            .where(
              (invite) =>
                  invite.status == FamilyInvitationStatus.pending &&
                  invite.expiresAt.isAfter(now),
            )
            .toList() ??
        [];
    _expiryTimer?.cancel();
    if (pending.isNotEmpty) {
      final expiry = pending
          .map((invite) => invite.expiresAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      _expiryTimer = Timer(expiry.difference(now), () {
        if (mounted) setState(() {});
      });
    }
    return Semantics(
      label: pending.isEmpty
          ? null
          : '${pending.length} pending ${pending.length == 1 ? 'invitation' : 'invitations'}',
      child: Badge(
        backgroundColor: Colors.red,
        isLabelVisible: pending.isNotEmpty,
        child: SvgPicture.asset(
          '${AppBottomNavigation._assetRoot}nav-more.svg',
          width: 30,
          height: 30,
          colorFilter: ColorFilter.mode(
            widget.selected ? const Color(0xFF0B7F7A) : const Color(0xFF5B6477),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
