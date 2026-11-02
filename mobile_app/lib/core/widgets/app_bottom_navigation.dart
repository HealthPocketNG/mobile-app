import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.currentIndex, super.key});

  final int currentIndex;

  static const _assetRoot = 'assets/dashboard/v2/';

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.1;
    final iconSize = compact ? 26.0 : 30.0;
    const routes = [
      AppRoute.dashboard,
      AppRoute.savings,
      AppRoute.findCare,
      AppRoute.activity,
      AppRoute.profile,
    ];
    const labels = ['Home', 'Savings', 'Pay', 'Activity', 'More'];
    const icons = [
      'nav-home.svg',
      'nav-savings.svg',
      'nav-pay.svg',
      'nav-activity.svg',
      'nav-more.svg',
    ];
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Container(
        height: compact ? 70 : 84,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8EDF0))),
        ),
        padding: EdgeInsets.only(top: compact ? 8 : 12),
        child: Row(
          children: [
            for (var index = 0; index < routes.length; index++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: index == currentIndex,
                  label: labels[index],
                  child: InkWell(
                    onTap: index == currentIndex
                        ? null
                        : () => Navigator.pushReplacementNamed(
                            context,
                            routes[index].path,
                          ),
                    child: Column(
                      children: [
                        index == 4
                            ? _FamilyInviteIcon(
                                selected: index == currentIndex,
                                size: iconSize,
                              )
                            : _navIcon(
                                icons[index],
                                index == currentIndex,
                                iconSize,
                              ),
                        SizedBox(height: compact ? 3 : 4),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: compact ? 11 : 12,
                            fontWeight: index == currentIndex
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: index == currentIndex
                                ? const Color(0xFF0B7F7A)
                                : const Color(0xFF5B6477),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _navIcon(String file, bool selected, double size) =>
      SvgPicture.asset(
        '$_assetRoot$file',
        width: size,
        height: size,
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
  const _FamilyInviteIcon({required this.selected, required this.size});

  final bool selected;
  final double size;

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
          width: widget.size,
          height: widget.size,
          colorFilter: ColorFilter.mode(
            widget.selected ? const Color(0xFF0B7F7A) : const Color(0xFF5B6477),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
