import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// A network image that never shows a broken image.
///
/// If [imageUrl] is empty/missing or the URL fails to load, a styled
/// placeholder with a category-aware icon is shown instead. This avoids
/// the Unsplash 404 errors that previously appeared in the browser console.
class FallbackImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final String? category;
  final ColorFilter? colorFilter;

  const FallbackImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.category,
    this.colorFilter,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    // The app previously seeded many Unsplash URLs that now return 404.
    // Rather than attempt the network request and log a console error, show
    // the placeholder immediately for empty or known-broken fallbacks.
    if (url.isEmpty || _isKnownBrokenFallback(url)) {
      return _wrap(_placeholder);
    }

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth =
        width != null && width!.isFinite ? (width! * dpr).toInt() : null;
    final cacheHeight =
        height != null && height!.isFinite ? (height! * dpr).toInt() : null;

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxWidthDiskCache: cacheWidth ?? 1200,
      maxHeightDiskCache: cacheHeight ?? 1200,
      placeholder: (_, __) => _loadingBox,
      errorWidget: (_, __, ___) => _placeholder,
    );

    final effectiveFilter = colorFilter ?? _defaultColorFilter;
    if (effectiveFilter != null) {
      image = ColorFiltered(
        colorFilter: effectiveFilter,
        child: image,
      );
    }

    return _wrap(image);
  }

  /// Makes food/restaurant images look richer and more appetising by boosting
  /// saturation and contrast slightly.
  static const _vividFoodFilter = ColorFilter.matrix([
    // Saturation 1.3 + brightness lift for stronger, more visible colours.
    1.2331, -0.2145, -0.0216, 0, 0.06,
    -0.0639, 1.0855, -0.0216, 0, 0.06,
    -0.0639, -0.2145, 1.2784, 0, 0.06,
    0, 0, 0, 1, 0,
  ]);

  ColorFilter? get _defaultColorFilter {
    final c = (category ?? '').toLowerCase();
    if (c.contains('food') ||
        c.contains('restaurant') ||
        c.contains('cafe') ||
        c.contains('dining')) {
      return _vividFoodFilter;
    }
    return null;
  }

  Widget _wrap(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }

  static bool _isKnownBrokenFallback(String url) {
    // Old Unsplash placeholder domains/IDs seeded into Firestore that now 404.
    if (url.contains('images.unsplash.com')) return true;
    final lower = url.toLowerCase();
    if (lower == 'null' || lower == 'none' || lower == 'n/a') return true;
    return false;
  }

  Widget get _loadingBox => Container(
        width: width,
        height: height,
        color: AppPalette.surfaceAlt,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget get _placeholder => Container(
        width: width,
        height: height,
        color: AppPalette.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(
          _iconForCategory,
          color: AppPalette.mutedText,
          size: _iconSize,
        ),
      );

  double get _iconSize {
    final shortest = (width ?? height ?? 48).clamp(24.0, 64.0);
    return shortest * 0.35;
  }

  IconData get _iconForCategory {
    final c = (category ?? '').toLowerCase();
    if (c.contains('food') ||
        c.contains('restaurant') ||
        c.contains('cafe') ||
        c.contains('dining')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('event') || c.contains('festival')) {
      return Icons.event_rounded;
    }
    if (c.contains('stadium') || c.contains('sport')) {
      return Icons.sports_rounded;
    }
    if (c.contains('park') || c.contains('garden')) {
      return Icons.park_rounded;
    }
    if (c.contains('museum') || c.contains('gallery')) {
      return Icons.museum_rounded;
    }
    if (c.contains('cinema') || c.contains('movie') || c.contains('theatre')) {
      return Icons.movie_rounded;
    }
    return Icons.image_rounded;
  }
}
