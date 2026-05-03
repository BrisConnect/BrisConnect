import 'dart:math';

import 'package:flutter/material.dart';

class AppPalette {
  static const Color background  = Color(0xFFF7F4ED);  // warm cream / beige
  static const Color surface     = Color(0xFFFFFDF8);  // near-white
  static const Color surfaceAlt  = Color(0xFFFFF8EA);  // warm gold tint
  static const Color ochre       = Color(0xFFC1440E);  // burnt orange (primary CTA)
  static const Color gold        = Color(0xFFD4A017);  // secondary accent
  static const Color brown       = Color(0xFF5C3D2E);  // earthy dark brown
  static const Color deepBlue    = Color(0xFF1E3A5F);  // headings / nav
  static const Color charcoal    = Color(0xFF2B2B2B);  // body text
  static const Color mutedText   = Color(0xFF6B675F);  // subtitles
  static const Color border      = Color(0xFFE4D8C4);  // card borders
  static const Color cardShadow  = Color(0x16000000);  // box shadows
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple dot-grid painter (subtle overlay for content screens)
// ─────────────────────────────────────────────────────────────────────────────

class DotPatternPainter extends CustomPainter {
  const DotPatternPainter({
    this.dotRadius = 3.0,
    this.spacing = 28.0,
    this.dotColor = AppPalette.brown,
    this.opacity = 0.07,
  });

  final double dotRadius;
  final double spacing;
  final Color dotColor;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      final xOffset = row.isOdd ? spacing / 2 : 0.0;
      for (int col = 0; col < cols; col++) {
        canvas.drawCircle(
          Offset(col * spacing + xOffset, row * spacing),
          dotRadius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) =>
      dotRadius != oldDelegate.dotRadius ||
      spacing != oldDelegate.spacing ||
      dotColor != oldDelegate.dotColor ||
      opacity != oldDelegate.opacity;
}

class DotPatternOverlay extends StatelessWidget {
  const DotPatternOverlay({
    super.key,
    this.dotRadius = 3.0,
    this.spacing = 28.0,
    this.dotColor = AppPalette.brown,
    this.opacity = 0.07,
  });

  final double dotRadius;
  final double spacing;
  final Color dotColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: DotPatternPainter(
            dotRadius: dotRadius,
            spacing: spacing,
            dotColor: dotColor,
            opacity: opacity,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rich Aboriginal dot-art painter (full-screen background)
// ─────────────────────────────────────────────────────────────────────────────

/// Earthy color palette for the dot art.
const _artColors = <Color>[
  Color(0xFF3D2214), // dark earth
  Color(0xFF5C3D2E), // medium brown
  Color(0xFF7A4E30), // warm brown
  Color(0xFF8B6914), // dark gold
  Color(0xFFA0522D), // sienna
  Color(0xFFC1440E), // burnt orange
  Color(0xFFC28820), // ochre
  Color(0xFFD4A017), // gold
  Color(0xFFD2B48C), // tan
  Color(0xFFE8C87A), // light gold
  Color(0xFFF5DEB3), // wheat
  Color(0xFFEED9B7), // cream
];

/// Aboriginal-inspired dot art with flowing wave bands and concentric circles.
///
/// Produces a rich, warm background similar to traditional Aboriginal artwork.
/// Uses a deterministic [seed] so the pattern is identical across rebuilds.
class AboriginalDotArtPainter extends CustomPainter {
  const AboriginalDotArtPainter({this.seed = 42});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // Sandy base fill
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFD2BA8A),
    );

    final rng = Random(seed);

    _paintWaveBands(canvas, size, rng);
    _paintConcentricClusters(canvas, size, rng);
    _paintScatterDots(canvas, size, rng);
  }

  // ── Flowing diagonal wave bands ──────────────────────────────────────────

  void _paintWaveBands(Canvas canvas, Size size, Random rng) {
    final bandCount = 12 + rng.nextInt(4);
    final diag = sqrt(size.width * size.width + size.height * size.height);

    for (int b = 0; b < bandCount; b++) {
      // Each band sweeps diagonally across the canvas.
      final baseT = (b / bandCount) - 0.1 + rng.nextDouble() * 0.06;
      final amplitude = diag * (0.04 + rng.nextDouble() * 0.04);
      final freq = 1.2 + rng.nextDouble() * 1.6;
      final phase = rng.nextDouble() * pi * 2;
      final angle = -0.35 + rng.nextDouble() * 0.2; // slight rotation
      final cosA = cos(angle);
      final sinA = sin(angle);

      final rowCount = 3 + rng.nextInt(4);
      final rowGap = 7.0 + rng.nextDouble() * 3.0;
      final dotGap = 7.0 + rng.nextDouble() * 3.0;
      final baseColorIdx = rng.nextInt(_artColors.length);

      for (int row = 0; row < rowCount; row++) {
        final color = _artColors[(baseColorIdx + row) % _artColors.length];
        final dotR = 2.4 + rng.nextDouble() * 1.8;
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        for (double t = -0.1; t <= 1.1; t += dotGap / diag) {
          // Position along the diagonal
          final px = t * diag;
          // Perpendicular offset (wave + row spacing)
          final wave = amplitude * sin(freq * t * pi * 2 + phase);
          final py = baseT * diag + row * rowGap + wave;

          // Rotate into canvas space
          final x = px * cosA - py * sinA;
          final y = px * sinA + py * cosA;

          if (x >= -dotR && x <= size.width + dotR &&
              y >= -dotR && y <= size.height + dotR) {
            canvas.drawCircle(Offset(x, y), dotR, paint);
          }
        }
      }
    }
  }

  // ── Concentric dot-circle clusters ───────────────────────────────────────

  void _paintConcentricClusters(Canvas canvas, Size size, Random rng) {
    final clusterCount = 5 + rng.nextInt(4);

    for (int c = 0; c < clusterCount; c++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final maxRadius = 50.0 + rng.nextDouble() * 80.0;
      final ringCount = 5 + rng.nextInt(5);
      final baseColorIdx = rng.nextInt(_artColors.length);

      for (int ring = 0; ring < ringCount; ring++) {
        final radius = maxRadius * (ring + 1) / ringCount;
        final circumference = 2 * pi * radius;
        final dotGap = 7.0 + rng.nextDouble() * 2.0;
        final dotCount = max(6, (circumference / dotGap).round());
        final color = _artColors[(baseColorIdx + ring) % _artColors.length];
        final dotR = 2.2 + rng.nextDouble() * 1.6;
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        final angleOffset = rng.nextDouble() * pi * 2;

        for (int d = 0; d < dotCount; d++) {
          final a = angleOffset + (d / dotCount) * pi * 2;
          final x = cx + radius * cos(a);
          final y = cy + radius * sin(a);
          if (x >= -dotR && x <= size.width + dotR &&
              y >= -dotR && y <= size.height + dotR) {
            canvas.drawCircle(Offset(x, y), dotR, paint);
          }
        }
      }

      // Center dot
      canvas.drawCircle(
        Offset(cx, cy),
        3.5 + rng.nextDouble() * 2,
        Paint()
          ..color = _artColors[baseColorIdx]
          ..style = PaintingStyle.fill,
      );
    }
  }

  // ── Scattered fill dots ──────────────────────────────────────────────────

  void _paintScatterDots(Canvas canvas, Size size, Random rng) {
    final count = (size.width * size.height / 400).round();
    for (int i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 1.2 + rng.nextDouble() * 1.5;
      final color = _artColors[rng.nextInt(_artColors.length)];
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = color.withValues(alpha: 0.3 + rng.nextDouble() * 0.4)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(AboriginalDotArtPainter oldDelegate) =>
      seed != oldDelegate.seed;
}

/// Full-screen Aboriginal dot-art background widget.
///
/// Caches the painting into a [RepaintBoundary] so it only paints once.
class AboriginalDotArtBackground extends StatelessWidget {
  const AboriginalDotArtBackground({super.key, this.seed = 42});

  final int seed;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: CustomPaint(
            painter: AboriginalDotArtPainter(seed: seed),
          ),
        ),
      ),
    );
  }
}