import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:healthpocket/core/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.currentIndex, super.key});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.inkMuted,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
      height: 72,
      backgroundColor: AppColors.surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.inkMuted,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        final route = switch (index) {
          0 => AppRoute.dashboard,
          1 => AppRoute.savings,
          3 => AppRoute.findCare,
          4 => AppRoute.profile,
          _ => null,
        };
        if (route == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pay will be available soon.')),
          );
          return;
        }
        Navigator.pushReplacementNamed(context, route.path);
      },
        destinations: const [
        NavigationDestination(
          icon: Icon(LucideIcons.house),
          selectedIcon: Icon(LucideIcons.house),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.piggyBank),
          selectedIcon: Icon(LucideIcons.piggyBank),
          label: 'Savings',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.scanQrCode),
          selectedIcon: Icon(LucideIcons.scanQrCode),
          label: 'Pay',
        ),
        NavigationDestination(
          icon: Icon(LucideIcons.mapPin),
          selectedIcon: Icon(LucideIcons.mapPin),
          label: 'Care',
        ),
        NavigationDestination(
          icon: _FamilyInviteIcon(icon: LucideIcons.menu),
          selectedIcon: _FamilyInviteIcon(icon: LucideIcons.menu),
          label: 'More',
        ),
        ],
      ),
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
