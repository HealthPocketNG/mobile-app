import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthpocket/features/family/application/family_pocket_store.dart';
import 'package:healthpocket/features/family/domain/family_pocket.dart';
import 'package:healthpocket/app/app_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentIndex,
    this.allowSelectedNavigation = false,
    this.assetRootOverride,
    this.iconFiles,
    this.useAssetColorsOverride,
    super.key,
  });

  final int currentIndex;
  final bool allowSelectedNavigation;
  final String? assetRootOverride;
  final List<String>? iconFiles;
  final bool? useAssetColorsOverride;

  static const _assetRoot = 'assets/dashboard/v2/';

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.1;
    final savingsDesign = currentIndex == 1;
    final assetRoot =
        assetRootOverride ??
        (savingsDesign ? 'assets/savings/v2/' : _assetRoot);
    final useAssetColors =
        useAssetColorsOverride ?? (savingsDesign || iconFiles != null);
    final iconSize = compact ? 26.0 : 30.0;
    const routes = [
      AppRoute.dashboard,
      AppRoute.savings,
      AppRoute.findCare,
      AppRoute.activity,
      AppRoute.profile,
    ];
    const labels = ['Home', 'Savings', 'Pay', 'Activity', 'More'];
    const defaultIcons = [
      'nav-home.svg',
      'nav-savings.svg',
      'nav-pay.svg',
      'nav-activity.svg',
      'nav-more.svg',
    ];
    final icons = iconFiles ?? defaultIcons;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Container(
        height: compact ? 64 : 74,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8EDF0))),
        ),
        padding: EdgeInsets.only(top: compact ? 6 : 8),
        child: Row(
          children: [
            for (var index = 0; index < routes.length; index++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: index == currentIndex,
                  label: labels[index],
                  child: InkWell(
                    onTap: index == currentIndex && !allowSelectedNavigation
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
                                assetRoot: assetRoot,
                                assetFile: icons[index],
                                useAssetColors: useAssetColors,
                              )
                            : _navIcon(
                                assetRoot,
                                icons[index],
                                index == currentIndex,
                                iconSize,
                                useAssetColors,
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

  static Widget _navIcon(
    String assetRoot,
    String file,
    bool selected,
    double size,
    bool useAssetColors,
  ) => SvgPicture.asset(
    '$assetRoot$file',
    width: size,
    height: size,
    colorFilter: useAssetColors
        ? null
        : ColorFilter.mode(
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
  const _FamilyInviteIcon({
    required this.selected,
    required this.size,
    required this.assetRoot,
    required this.assetFile,
    required this.useAssetColors,
  });

  final bool selected;
  final double size;
  final String assetRoot;
  final String assetFile;
  final bool useAssetColors;

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
          '${widget.assetRoot}${widget.assetFile}',
          width: widget.size,
          height: widget.size,
          colorFilter: widget.useAssetColors
              ? null
              : ColorFilter.mode(
                  widget.selected
                      ? const Color(0xFF0B7F7A)
                      : const Color(0xFF5B6477),
                  BlendMode.srcIn,
                ),
        ),
      ),
    );
  }
}
