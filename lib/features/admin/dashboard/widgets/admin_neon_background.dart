import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Neon tech background for the Admin Analytics Portal only.
///
/// Deep navy/near-black base with orange/blue neon glow in opposite
/// corners, thin light trails, faint network lines and subtle
/// food-business line-art scattered around the perimeter. The central
/// area is intentionally kept dark and calm so dashboard cards/charts
/// stay readable. Purely decorative - never intercepts input.
class AdminNeonBackground extends StatefulWidget {
  const AdminNeonBackground({super.key});

  @override
  State<AdminNeonBackground> createState() => _AdminNeonBackgroundState();
}

class _AdminNeonBackgroundState extends State<AdminNeonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  static const _neonOrange = Color(0xFFFF7A1A);
  static const _neonBlue = Color(0xFF22C7FF);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF060812),
                Color(0xFF0A0E1C),
                Color(0xFF07090F),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Corner glow blobs - orange top-left, blue bottom-right.
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = 0.28 + (_pulse.value * 0.14);
                  return Positioned(
                    top: -180,
                    left: -180,
                    child: _GlowBlob(color: _neonOrange, opacity: t, size: 560),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = 0.42 - (_pulse.value * 0.14);
                  return Positioned(
                    bottom: -200,
                    right: -200,
                    child: _GlowBlob(color: _neonBlue, opacity: t, size: 620),
                  );
                },
              ),
              // Thin light trails, network lines and faint skyline.
              CustomPaint(
                painter: _NeonLinePainter(
                  orange: _neonOrange,
                  blue: _neonBlue,
                ),
              ),
              // Perimeter food-business line art.
              const _PerimeterFoodIcons(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.opacity, required this.size});

  final Color color;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity.clamp(0.0, 1.0)),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _NeonLinePainter extends CustomPainter {
  _NeonLinePainter({required this.orange, required this.blue});

  final Color orange;
  final Color blue;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLightTrails(canvas, size);
    _paintNetworkLines(canvas, size);
    _paintSkyline(canvas, size);
  }

  void _paintLightTrails(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final trail1 = Path()
      ..moveTo(-40, h * 0.06)
      ..quadraticBezierTo(w * 0.18, h * 0.02, w * 0.42, h * 0.12);
    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = LinearGradient(
        colors: [orange.withValues(alpha: 0.55), orange.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(-40, 0, w * 0.5, h * 0.15));
    canvas.drawPath(trail1, paint1);

    final trail2 = Path()
      ..moveTo(w + 40, h * 0.92)
      ..quadraticBezierTo(w * 0.82, h * 0.98, w * 0.58, h * 0.88);
    final paint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = LinearGradient(
        colors: [blue.withValues(alpha: 0.55), blue.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(w * 0.5, h * 0.85, w * 0.5, h * 0.15));
    canvas.drawPath(trail2, paint2);

    // Thin vertical accent trails along the far edges.
    final leftEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          orange.withValues(alpha: 0.35),
          orange.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, 4, h * 0.4));
    canvas.drawLine(Offset(6, 0), Offset(6, h * 0.4), leftEdge);

    final rightEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          blue.withValues(alpha: 0.35),
          blue.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w - 4, h * 0.6, 4, h * 0.4));
    canvas.drawLine(Offset(w - 6, h), Offset(w - 6, h * 0.6), rightEdge);
  }

  void _paintNetworkLines(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(7);

    void cluster(Offset origin, Color color, double spread, int nodes) {
      final points = <Offset>[origin];
      for (var i = 0; i < nodes; i++) {
        points.add(
          origin +
              Offset(
                (rnd.nextDouble() - 0.5) * spread,
                (rnd.nextDouble() - 0.5) * spread,
              ),
        );
      }
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..strokeWidth = 0.8;
      final dotPaint = Paint()..color = color.withValues(alpha: 0.35);
      for (var i = 1; i < points.length; i++) {
        canvas.drawLine(points[0], points[i], linePaint);
        canvas.drawCircle(points[i], 1.6, dotPaint);
      }
      canvas.drawCircle(points[0], 2.2, dotPaint);
    }

    cluster(Offset(w * 0.08, h * 0.22), orange, 90, 4);
    cluster(Offset(w * 0.92, h * 0.78), blue, 90, 4);
  }

  void _paintSkyline(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h - 2;
    final rnd = math.Random(3);
    final path = Path()..moveTo(0, baseY);
    var x = 0.0;
    while (x < w) {
      final buildingWidth = 18.0 + rnd.nextDouble() * 26;
      final buildingHeight = 10.0 + rnd.nextDouble() * 34;
      path.lineTo(x, baseY - buildingHeight);
      path.lineTo(x + buildingWidth, baseY - buildingHeight);
      x += buildingWidth;
    }
    path.lineTo(w, baseY);

    final skylinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = blue.withValues(alpha: 0.10);
    canvas.drawPath(path, skylinePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonLinePainter oldDelegate) => false;
}

/// Abstract, very faint food-business icons placed only in the outer edge
/// band of the page (fractional positions, always within ~10% of an edge)
/// so they never creep into the central content area on any screen size.
class _PerimeterFoodIcons extends StatelessWidget {
  const _PerimeterFoodIcons();

  static const _orange = Color(0xFFFF8C3D);
  static const _blue = Color(0xFF3DD6FF);

  // (fractionX, fractionY, icon, color, size) - fractions always fall
  // within the outer ~10% edge band on both axes.
  static const _items = <(double, double, IconData, Color, double)>[
    (0.015, 0.035, Icons.storefront_outlined, _orange, 28),
    (0.12, 0.02, Icons.shopping_bag_outlined, _orange, 18),
    (0.965, 0.045, Icons.location_on_outlined, _blue, 24),
    (0.985, 0.16, Icons.local_cafe_outlined, _blue, 20),
    (0.02, 0.94, Icons.fastfood_outlined, _orange, 26),
    (0.14, 0.965, Icons.restaurant_outlined, _orange, 18),
    (0.95, 0.955, Icons.ramen_dining_outlined, _blue, 26),
    (0.83, 0.96, Icons.dinner_dining_outlined, _blue, 18),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            for (final item in _items)
              Positioned(
                left: item.$1 * w,
                top: item.$2 * h,
                child: _GlowIcon(icon: item.$3, color: item.$4, size: item.$5),
              ),
          ],
        );
      },
    );
  }
}

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Icon(icon, size: size * 1.4, color: color.withValues(alpha: 0.13)),
        ),
        Icon(icon, size: size, color: color.withValues(alpha: 0.09)),
      ],
    );
  }
}
