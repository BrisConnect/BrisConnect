import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart'
    as cluster;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/map/map_models.dart';

/// Generates custom Google Maps marker bitmaps for [MapPin]s and clusters.
class MapMarkerHelper {
  MapMarkerHelper() {
    _loadMarkerShadow();
  }

  final Map<String, BitmapDescriptor> _pinCache = {};
  final Map<String, BitmapDescriptor> _clusterCache = {};
  BitmapDescriptor? _userLocationBitmapCache;

  ui.Image? _shadowImage;
  bool _shadowLoading = false;

  /// Warm up the shadow asset so first markers render without a flash.
  Future<void> preload() async {
    await _loadMarkerShadow();
  }

  Future<void> _loadMarkerShadow() async {
    if (_shadowLoading || _shadowImage != null) return;
    _shadowLoading = true;
    try {
      final data = await rootBundle.load('assets/images/marker_shadow.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _shadowImage = frame.image;
    } catch (_) {
      // Shadow is optional; markers still render without it.
    } finally {
      _shadowLoading = false;
    }
  }

  /// Clear caches. Call this when the theme or marker style changes.
  void clearCache() {
    _pinCache.clear();
    _clusterCache.clear();
  }

  /// Build a user-location marker bitmap.
  ///
  /// If the signed-in visitor has uploaded a profile image (URL or base64),
  /// it is clipped into a circular avatar. Otherwise a person icon is shown.
  /// The result is cached so repeated GPS updates don't reload the image.
  Future<BitmapDescriptor> bitmapForUserLocation() async {
    final cached = _userLocationBitmapCache;
    if (cached != null) return cached;

    const size = 56.0;
    final visitor = VisitorAuth.currentVisitor;
    final imageBytes = await _resolveVisitorProfileImageBytes(visitor)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final center = size / 2;

    // Accuracy halo.
    final haloPaint = ui.Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.22)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(ui.Offset(center, center), center - 2, haloPaint);

    // Clip to circular avatar shape.
    final avatarRect = ui.Rect.fromCircle(
      center: ui.Offset(center, center),
      radius: 18,
    );
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(avatarRect));

    if (imageBytes != null && imageBytes.isNotEmpty) {
      // Draw profile picture, filling the circle and cropped to fit.
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final srcSize = math.min(image.width.toDouble(), image.height.toDouble());
      final srcRect = ui.Rect.fromCenter(
        center: ui.Offset(image.width / 2, image.height / 2),
        width: srcSize,
        height: srcSize,
      );
      canvas.drawImageRect(
        image,
        srcRect,
        avatarRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    } else {
      // White background for the person icon fallback.
      final bgPaint = ui.Paint()
        ..color = Colors.white
        ..style = ui.PaintingStyle.fill;
      canvas.drawCircle(ui.Offset(center, center), 18, bgPaint);

      const iconData = Icons.person_rounded;
      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      iconPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          fontSize: 22,
          color: const Color(0xFF3B82F6),
          fontWeight: FontWeight.w700,
        ),
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        ui.Offset(
            center - iconPainter.width / 2, center - iconPainter.height / 2),
      );
    }

    // Blue border ring (drawn after removing the circular clip).
    canvas.restore();
    final borderPaint = ui.Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(ui.Offset(center, center), 18, borderPaint);

    final img = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(data!.buffer.asUint8List());
    _userLocationBitmapCache = descriptor;
    return descriptor;
  }

  /// Clears the cached user-location marker so the next GPS update reloads
  /// the visitor's current profile picture.
  void clearUserLocationCache() => _userLocationBitmapCache = null;

  Future<Uint8List?> _resolveVisitorProfileImageBytes(
      VisitorUser? visitor) async {
    final imageUrl = visitor?.profileImageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Failed to load visitor profile image: $e');
      }
    }

    final base64String = visitor?.profileImageBase64?.trim() ?? '';
    if (base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }

  /// Build a [BitmapDescriptor] for an individual pin.
  Future<BitmapDescriptor> bitmapForPin(
    MapPin pin, {
    bool selected = false,
  }) async {
    final status = statusForPin(pin);
    final featured = _featuredIcon(pin);
    final cacheKey =
        '${pin.type.name}:${status.name}:${featured.key}:$selected';
    if (_pinCache.containsKey(cacheKey)) return _pinCache[cacheKey]!;

    final color = _pinColor(pin);
    final bitmap = await _drawPin(
      size: selected ? 72 : 56,
      color: color,
      featuredIcon: featured,
      iconSize: selected ? 22 : 18,
      selected: selected,
    );
    final descriptor = BitmapDescriptor.bytes(bitmap);
    _pinCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Build a [BitmapDescriptor] for a cluster of pins.
  ///
  /// Cluster colour is based on the number of contained items so users can
  /// quickly identify dense areas:
  ///   1–10  -> green
  ///   11–30 -> yellow
  ///   31–60 -> orange
  ///   60+   -> red
  Future<BitmapDescriptor> bitmapForCluster(
    cluster.Cluster<MapPin> cluster, {
    double zoom = 12,
  }) async {
    final count = cluster.count;
    final color = _clusterColor(count);
    final cacheKey = 'cluster:$count';
    if (_clusterCache.containsKey(cacheKey)) return _clusterCache[cacheKey]!;

    final size = _clusterSize(count, zoom);
    final bitmap = await _drawCluster(
      size: size,
      color: color,
      count: count,
    );
    final descriptor = BitmapDescriptor.bytes(bitmap);
    _clusterCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Density-aware cluster colour.
  Color _clusterColor(int count) {
    if (count <= 10) return const Color(0xFF10B981); // Green
    if (count <= 30) return const Color(0xFFFACC15); // Yellow
    if (count <= 60) return AppPalette.ochre; // Orange
    return const Color(0xFFEF4444); // Red
  }

  /// Determine the visible status priority for a pin.
  MapPinStatus statusForPin(MapPin pin) {
    if (pin.type != MapPinType.food) return MapPinStatus.verified;
    if (pin.isOpenNow == false || pin.isClosingSoon == true) {
      return MapPinStatus.closed;
    }
    if (pin.isPremium) return MapPinStatus.premium;
    if (pin.isPopular) return MapPinStatus.popular;
    if (pin.isVerified) return MapPinStatus.verified;
    return MapPinStatus.open;
  }

  /// Status-aware colour for business pins.
  static Color statusColor(MapPinStatus status) {
    switch (status) {
      case MapPinStatus.open:
        return const Color(0xFF10B981); // Green
      case MapPinStatus.popular:
        return AppPalette.ochre; // Orange
      case MapPinStatus.premium:
        return const Color(0xFF8B5CF6); // Purple
      case MapPinStatus.verified:
        return AppPalette.deepBlue; // Blue
      case MapPinStatus.closed:
        return const Color(0xFF9CA3AF); // Grey
    }
  }

  /// Type-aware colour for non-business pins.
  Color _typeColor(MapPinType type) {
    switch (type) {
      case MapPinType.event:
        return const Color(0xFFF59E0B); // Amber
      case MapPinType.attraction:
        return const Color(0xFF0EA5E9); // Sky
      case MapPinType.stadium:
        return const Color(0xFFEC4899); // Pink
      case MapPinType.olympicVenue:
        return const Color(0xFF7C3AED); // Violet
      case MapPinType.culturalVenue:
        return const Color(0xFF14B8A6); // Teal
      case MapPinType.food:
        return AppPalette.ochre;
    }
  }

  /// Public colour for a pin. Business pins use status colours; other pins
  /// keep type-based colours so events/attractions remain distinguishable.
  Color _pinColor(MapPin pin) {
    if (pin.type == MapPinType.food) return statusColor(statusForPin(pin));
    return _typeColor(pin.type);
  }

  /// Determine whether a food pin is featured enough to display a special icon.
  /// Featured priority: Premium > Trending > Verified > default.
  MapPinIcon _featuredIcon(MapPin pin) {
    if (pin.type != MapPinType.food) {
      return MapPinIcon(type: pin.type);
    }
    if (pin.isPremium) return const MapPinIcon.featured(FeaturedMarker.premium);
    if (pin.isPopular) {
      return const MapPinIcon.featured(FeaturedMarker.trending);
    }
    if (pin.isVerified) {
      return const MapPinIcon.featured(FeaturedMarker.verified);
    }
    return MapPinIcon(type: pin.type);
  }

  double _clusterSize(int count, double zoom) {
    final digits = count.toString().length;
    final base = 48.0 + (digits - 1) * 10;
    return math.min(base + zoom * 0.5, 90);
  }

  /// Draw a teardrop pin with a Material 3 style.
  Future<Uint8List> _drawPin({
    required double size,
    required Color color,
    required MapPinIcon featuredIcon,
    required double iconSize,
    required bool selected,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final center = size / 2;

    // Optional shadow.
    if (_shadowImage != null) {
      final shadowSize = size * 0.9;
      canvas.drawImageRect(
        _shadowImage!,
        ui.Rect.fromLTRB(
          0,
          0,
          _shadowImage!.width.toDouble(),
          _shadowImage!.height.toDouble(),
        ),
        ui.Rect.fromCenter(
          center: ui.Offset(center, size - 4),
          width: shadowSize,
          height: shadowSize * 0.4,
        ),
        ui.Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
    }

    // Pin body path.
    final path = ui.Path();
    final headRadius = size * 0.38;
    final pinBottomY = size - 4;
    path.addOval(
      ui.Rect.fromCenter(
        center: ui.Offset(center, headRadius + 4),
        width: headRadius * 2,
        height: headRadius * 2,
      ),
    );
    path.moveTo(center - headRadius * 0.55, headRadius + headRadius * 0.55);
    path.quadraticBezierTo(
      center,
      headRadius * 2.15,
      center,
      pinBottomY,
    );
    path.quadraticBezierTo(
      center,
      headRadius * 2.15,
      center + headRadius * 0.55,
      headRadius + headRadius * 0.55,
    );
    path.close();

    // Gradient fill.
    final fillPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(center, 0),
        ui.Offset(center, size),
        [
          color.withValues(alpha: 1),
          color.withValues(alpha: 0.85),
        ],
      )
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // White border.
    final strokePaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = selected ? 4 : 3;
    canvas.drawPath(path, strokePaint);

    // Main icon.
    final iconData = featuredIcon.icon;
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontFamily: iconData.fontFamily,
        fontSize: iconSize,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      ui.Offset(center - iconPainter.width / 2,
          headRadius + 4 - iconPainter.height / 2),
    );

    // Featured badge overlay for premium/trending/verified food pins.
    if (featuredIcon.badge != null) {
      final badge = featuredIcon.badge!;
      final badgeRadius = size * 0.16;
      final badgeCenter = ui.Offset(size - badgeRadius - 2, badgeRadius + 2);
      final badgePaint = ui.Paint()
        ..color = badge.backgroundColor
        ..style = ui.PaintingStyle.fill;
      canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);

      final badgeIconPainter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: String.fromCharCode(badge.icon.codePoint),
          style: TextStyle(
            fontFamily: badge.icon.fontFamily,
            fontSize: badgeRadius * 1.1,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        )
        ..layout();
      badgeIconPainter.paint(
        canvas,
        ui.Offset(
          badgeCenter.dx - badgeIconPainter.width / 2,
          badgeCenter.dy - badgeIconPainter.height / 2,
        ),
      );
    }

    final img = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Draw a circular cluster marker.
  Future<Uint8List> _drawCluster({
    required double size,
    required Color color,
    required int count,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);
    final center = size / 2;

    // Outer ring.
    final outerPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(ui.Offset(center, center), center - 2, outerPaint);

    // Inner gradient.
    final innerPaint = ui.Paint()
      ..shader = ui.Gradient.radial(
        ui.Offset(center, center),
        center - 6,
        [
          color.withValues(alpha: 1),
          color.withValues(alpha: 0.82),
        ],
      )
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(ui.Offset(center, center), center - 6, innerPaint);

    // Count text.
    final text = count > 99 ? '99+' : '$count';
    final fontSize = size / (text.length > 2 ? 2.8 : 2.2);
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      ui.Offset(
          center - textPainter.width / 2, center - textPainter.height / 2),
    );

    final img = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// Helpers that do not need an instance.
extension MapPinStatusX on MapPinStatus {
  String get label {
    switch (this) {
      case MapPinStatus.open:
        return 'Open';
      case MapPinStatus.popular:
        return 'Popular';
      case MapPinStatus.premium:
        return 'Premium';
      case MapPinStatus.verified:
        return 'Verified';
      case MapPinStatus.closed:
        return 'Closed';
    }
  }
}

extension MapPinTypeX on MapPinType {
  String get label {
    switch (this) {
      case MapPinType.event:
        return 'Event';
      case MapPinType.attraction:
        return 'Attraction';
      case MapPinType.stadium:
        return 'Stadium';
      case MapPinType.olympicVenue:
        return 'Olympic Venue';
      case MapPinType.culturalVenue:
        return 'Cultural History';
      case MapPinType.food:
        return 'Food';
    }
  }

  IconData get icon {
    switch (this) {
      case MapPinType.event:
        return Icons.event_rounded;
      case MapPinType.attraction:
        return Icons.place_rounded;
      case MapPinType.stadium:
        return Icons.stadium_rounded;
      case MapPinType.olympicVenue:
        return Icons.emoji_events_rounded;
      case MapPinType.culturalVenue:
        return Icons.account_balance_rounded;
      case MapPinType.food:
        return Icons.restaurant_rounded;
    }
  }
}

/// Visual badge overlay for featured food businesses.
enum FeaturedMarker {
  premium,
  trending,
  verified,
}

extension FeaturedMarkerX on FeaturedMarker {
  IconData get icon {
    switch (this) {
      case FeaturedMarker.premium:
        return Icons.workspace_premium_rounded;
      case FeaturedMarker.trending:
        return Icons.local_fire_department_rounded;
      case FeaturedMarker.verified:
        return Icons.verified_rounded;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case FeaturedMarker.premium:
        return const Color(0xFF8B5CF6);
      case FeaturedMarker.trending:
        return const Color(0xFFF59E0B);
      case FeaturedMarker.verified:
        return AppPalette.deepBlue;
    }
  }
}

/// Describes the icon and optional featured badge for a marker.
@immutable
class MapPinIcon {
  const MapPinIcon({required this.type}) : badge = null;

  const MapPinIcon.featured(this.badge) : type = MapPinType.food;

  final MapPinType type;
  final FeaturedMarker? badge;

  IconData get icon {
    if (badge != null) return type.icon;
    return type.icon;
  }

  String get key {
    if (badge == null) return 'type:${type.name}';
    return 'type:${type.name}:badge:${badge!.name}';
  }
}
