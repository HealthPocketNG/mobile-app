import 'package:flutter/material.dart';

/// Shared edge spacing and scroll feel for top-level vertical pages.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final vertical =
        details.direction == AxisDirection.down ||
        details.direction == AxisDirection.up;
    if (vertical && Scrollable.maybeOf(context) == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: child,
      );
    }
    return child;
  }
}
