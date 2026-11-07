/// Shared V2 display sizes for compact phone layouts.
/// Keeps supporting copy readable while bringing headlines and amounts into
/// the same visual rhythm across features.
abstract final class AppUiDensity {
  static double font(double size) {
    if (size >= 40) return size * .84;
    if (size >= 30) return size * .88;
    if (size >= 26) return size - 3;
    if (size >= 20) return size - 2;
    if (size >= 16) return size - 1;
    return size;
  }

  static const primaryButtonHeight = 48.0;
  static const secondaryButtonHeight = 44.0;
}
