import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.currentIndex, super.key});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      height: 72,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        final route = switch (index) {
          0 => AppRoute.dashboard,
          1 => AppRoute.savings,
          2 => AppRoute.familyPocket,
          4 => AppRoute.findCare,
          _ => AppRoute.profile,
        };
        Navigator.pushReplacementNamed(context, route.path);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.savings_outlined),
          selectedIcon: Icon(Icons.savings_rounded),
          label: 'Savings',
        ),
        NavigationDestination(
          icon: _FamilyInviteIcon(icon: Icons.groups_2_outlined),
          selectedIcon: _FamilyInviteIcon(icon: Icons.groups_2_rounded),
          label: 'Family',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_hospital_outlined),
          selectedIcon: Icon(Icons.local_hospital),
          label: 'Find care',
        ),
      ],
    );
  }
}

class FamilyInvitationScope extends InheritedNotifier<FamilyPocketStore> {
  const FamilyInvitationScope({
    required FamilyPocketStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);
}

class _FamilyInviteIcon extends StatefulWidget {
  const _FamilyInviteIcon({required this.icon});
  final IconData icon;

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
        child: Icon(widget.icon),
      ),
    );
  }
}
