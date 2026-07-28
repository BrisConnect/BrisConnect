import 'package:flutter/material.dart';

/// Standard breakpoints used across BrisConnect for responsive layouts.
///
/// These values are intentionally conservative so that phones in landscape
/// and small tablets still receive the mobile experience, while real desktop
/// web / large tablet windows get the expanded desktop UI.
class Breakpoints {
  Breakpoints._();

  /// Up to 767 logical pixels: phones and small handsets.
  static const double mobile = 768;

  /// 768 – 1023 logical pixels: tablets and small laptop windows.
  static const double tablet = 1024;

  /// 1024+ logical pixels: desktops, large tablets, and unfolded devices.
  static const double desktop = 1024;
}

/// Convenience helpers for querying the current screen size.
class ResponsiveUtils {
  ResponsiveUtils._();

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static double widthOf(BuildContext context) => sizeOf(context).width;

  static bool isMobile(BuildContext context) =>
      widthOf(context) < Breakpoints.mobile;

  static bool isTablet(BuildContext context) =>
      widthOf(context) >= Breakpoints.mobile &&
      widthOf(context) < Breakpoints.tablet;

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= Breakpoints.desktop;

  /// Returns the number of grid columns appropriate for the available width.
  ///
  /// [itemMinWidth] is the minimum width each grid item should have. The
  /// result is at least [minColumns] and at most [maxColumns].
  static int gridColumnCount(
    BuildContext context, {
    double itemMinWidth = 320,
    int minColumns = 1,
    int maxColumns = 4,
    double spacing = 16,
  }) {
    final width = widthOf(context);
    final cols = ((width + spacing) / (itemMinWidth + spacing)).floor();
    return cols.clamp(minColumns, maxColumns);
  }
}

/// A small helper widget that applies different padding based on the screen
/// width. This avoids scattering [LayoutBuilder]/[MediaQuery] checks
/// everywhere when only padding needs to change.
class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobile = const EdgeInsets.symmetric(horizontal: 16),
    this.tablet = const EdgeInsets.symmetric(horizontal: 32),
    this.desktop = const EdgeInsets.symmetric(horizontal: 48),
  });

  final Widget child;
  final EdgeInsets mobile;
  final EdgeInsets tablet;
  final EdgeInsets desktop;

  @override
  Widget build(BuildContext context) {
    final width = ResponsiveUtils.widthOf(context);
    final padding = width >= Breakpoints.tablet
        ? desktop
        : width >= Breakpoints.mobile
            ? tablet
            : mobile;
    return Padding(padding: padding, child: child);
  }
}
