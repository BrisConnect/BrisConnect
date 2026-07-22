import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/register_selection_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Fire-spark particle data
// ═══════════════════════════════════════════════════════════════════════════

class _Spark {
  _Spark(math.Random rng) { reset(rng, initial: true); }

  late double x, y, vx, vy, life, maxLife, radius;
  late Color color;

  static const _sparkColors = [
    Color(0xFFFFE082), // bright yellow
    Color(0xFFFFAB40), // amber
    Color(0xFFFF8F00), // deep amber
    Color(0xFFE8600A), // orange
    Color(0xFFC1440E), // burnt orange
    Color(0xFFFFFFFF), // white-hot
    Color(0xFFFFD54F), // light gold
  ];

  void reset(math.Random rng, {bool initial = false}) {
    // Spawn from a narrow horizontal band (fire tip zone).
    x = -0.08 + rng.nextDouble() * 0.16;            // ±8 % of width from centre
    y = 0.0;                                         // relative to spark origin
    vx = (rng.nextDouble() - 0.5) * 0.15;            // gentle horizontal drift
    vy = -(0.25 + rng.nextDouble() * 0.55);          // rise upward
    maxLife = 0.6 + rng.nextDouble() * 1.0;
    life = initial ? rng.nextDouble() * maxLife : 0;  // stagger on first frame
    radius = 1.2 + rng.nextDouble() * 2.8;
    color = _sparkColors[rng.nextInt(_sparkColors.length)];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Fire-spark painter (driven by elapsed seconds)
// ═══════════════════════════════════════════════════════════════════════════

class _FireSparkPainter extends CustomPainter {
  _FireSparkPainter({
    required this.sparks,
    required this.sparkOriginY,
    required this.elapsed,
  }) : super(repaint: elapsed);

  final List<_Spark> sparks;
  final double sparkOriginY;   // absolute Y in canvas coords
  final ValueNotifier<double> elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    for (final s in sparks) {
      final t = (s.life / s.maxLife).clamp(0.0, 1.0);
      if (t >= 1.0) continue;

      // Fade out and shrink near end of life.
      final opacity = (1.0 - t) * (1.0 - t);
      final r = s.radius * (1.0 - t * 0.5);

      final px = cx + s.x * size.width;
      final py = sparkOriginY + s.y * size.height * 0.35;

      if (px < -r || px > size.width + r || py < -r || py > size.height + r) {
        continue;
      }

      // Glow halo
      canvas.drawCircle(
        Offset(px, py),
        r * 2.5,
        Paint()
          ..color = s.color.withValues(alpha: opacity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Core spark
      canvas.drawCircle(
        Offset(px, py),
        r,
        Paint()..color = s.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_FireSparkPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// Welcome Screen
// ═══════════════════════════════════════════════════════════════════════════

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final AnimationController _sparkCtrl;
  late final AnimationController _logoIntroCtrl;
  late final Animation<double> _logoIntroScale;
  late final Animation<double> _logoIntroOpacity;
  final ValueNotifier<double> _elapsed = ValueNotifier(0);

  static const int _sparkCount = 35;
  late final List<_Spark> _sparks;
  final math.Random _rng = math.Random(99);
  double _lastT = 0;

  @override
  void initState() {
    super.initState();

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _logoIntroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _logoIntroScale = Tween<double>(begin: 0.60, end: 1.05)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_logoIntroCtrl);
    _logoIntroOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: const Interval(0.18, 1.0, curve: Curves.easeOut)))
        .animate(_logoIntroCtrl);

    // Spark ticker – runs ~60 fps
    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _sparkCtrl.addListener(_tickSparks);

    _sparks = List.generate(_sparkCount, (_) => _Spark(_rng));
  }

  void _tickSparks() {
    final now = _sparkCtrl.lastElapsedDuration?.inMicroseconds ?? 0;
    final sec = now / 1e6;
    final dt = (sec - _lastT).clamp(0.0, 0.05);
    _lastT = sec;

    for (final s in _sparks) {
      s.life += dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      // Add slight upward acceleration & random horizontal wobble
      s.vy -= 0.08 * dt;
      s.vx += ((_rng.nextDouble() - 0.5) * 0.3) * dt;

      if (s.life >= s.maxLife) {
        s.reset(_rng);
      }
    }
    _elapsed.value = sec;
  }

  @override
  void dispose() {
    _sparkCtrl.removeListener(_tickSparks);
    _sparkCtrl.dispose();
    _glowCtrl.dispose();
    _logoIntroCtrl.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = (screenWidth * 0.44).clamp(140.0, 210.0);

    // Spark origin: roughly at the top of the logo's fire tip.
    // Logo centre is at ~28 % from top; fire tip is ~logoSize*0.42 above centre.
    final logoTopFrac = 0.28;
    final sparkOriginY =
        screenHeight * logoTopFrac - logoSize * 0.42;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── L1: Aboriginal dot-art ──
          const AboriginalDotArtBackground(seed: 42),

          // ── L2: Dark warm cinematic overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.20),
                    radius: 1.1,
                    colors: [
                      const Color(0xFF2A1508).withValues(alpha: 0.60),
                      const Color(0xFF0F0804).withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── L3: Animated fire glow (radial) ──
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (context, _) {
                  final t = _glowCtrl.value;
                  final opacity = 0.22 + t * 0.20;
                  final radius = 0.36 + t * 0.10;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.30),
                        radius: radius,
                        colors: [
                          const Color(0xFFFF6D00)
                              .withValues(alpha: opacity),
                          const Color(0xFFD4A017)
                              .withValues(alpha: opacity * 0.40),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.38, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── L4: Bottom vignette ──
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF0F0804).withValues(alpha: 0.70),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── L5: Fire spark particles ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FireSparkPainter(
                  sparks: _sparks,
                  sparkOriginY: sparkOriginY,
                  elapsed: _elapsed,
                ),
              ),
            ),
          ),

          // ── L6: Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // ── Logo with Netflix-style intro animation ──
                  AnimatedBuilder(
                    animation: _logoIntroCtrl,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoIntroOpacity.value,
                        child: Transform.scale(
                          scale: _logoIntroScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (context, child) {
                        final t = _glowCtrl.value;
                        final spread = 12.0 + t * 14.0;
                        final a = 0.28 + t * 0.24;
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6D00)
                                    .withValues(alpha: a),
                                blurRadius: spread * 2.5,
                                spreadRadius: spread,
                              ),
                              BoxShadow(
                                color: const Color(0xFFFFAB40)
                                    .withValues(alpha: a * 0.30),
                                blurRadius: spread * 4,
                                spreadRadius: spread * 1.8,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/Brisconnect New.jpg',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Title ──
                  Text(
                    'BrisConnect+',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 18,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Subtitle (gold italic) ──
                  Text(
                    'Empowering local food businesses — discover, support & connect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFE8C87A),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Aboriginal dot-circle divider ──
                  const _DotCircleDivider(),

                  const SizedBox(height: 24),

                  // ── Welcome heading ──
                  Text(
                    'Welcome to BrisConnect+',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Description ──
                  Text(
                    'Brisbane\'s platform for local food businesses.\n'
                    'Discover, support and connect with small & medium food enterprises.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: const Color(0xFFEED9B7),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Get Started (orange gradient + arrow) ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6D00), Color(0xFFC1440E)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFC1440E).withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterSelectionScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Get Started'),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Log In (outlined + person icon) ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginSelectionScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: const Color(0xFFF5DEB3).withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                        backgroundColor: const Color(0x18FFFFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('Log In'),
                          SizedBox(width: 10),
                          Icon(Icons.person_outline_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Acknowledgment of Country ──
                  const Text(
                    'We acknowledge the Traditional Custodians of the land on '
                    'which Brisbane stands, and pay our respects to Elders '
                    'past, present, and emerging.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xAAEED9B7),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Aboriginal-style concentric dot-circle divider
// ═══════════════════════════════════════════════════════════════════════════

class _DotCircleDivider extends StatelessWidget {
  const _DotCircleDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: CustomPaint(painter: const _DotCirclePainter()),
    );
  }
}

class _DotCirclePainter extends CustomPainter {
  const _DotCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Centre dot
    canvas.drawCircle(
      Offset(cx, cy),
      3.0,
      Paint()..color = const Color(0xFFE8600A),
    );

    // Two concentric rings of dots
    const ringRadii = [8.0, 15.0];
    const ringDotCounts = [6, 10];
    const ringDotR = [1.8, 1.5];
    const ringColors = [Color(0xFFD4A017), Color(0xFFE8C87A)];

    for (int r = 0; r < ringRadii.length; r++) {
      final paint = Paint()..color = ringColors[r];
      for (int d = 0; d < ringDotCounts[r]; d++) {
        final angle = (d / ringDotCounts[r]) * math.pi * 2 - math.pi / 2;
        canvas.drawCircle(
          Offset(
            cx + ringRadii[r] * math.cos(angle),
            cy + ringRadii[r] * math.sin(angle),
          ),
          ringDotR[r],
          paint,
        );
      }
    }

    // Side dot rows
    const sideDots = 5;
    const sideGap = 7.0;
    const sideDotR = 2.0;
    final sidePaint = Paint()..color = const Color(0xFFE8600A);
    for (int i = 1; i <= sideDots; i++) {
      canvas.drawCircle(
        Offset(cx - 15.0 - i * sideGap, cy),
        sideDotR * (1.0 - i * 0.08),
        sidePaint,
      );
      canvas.drawCircle(
        Offset(cx + 15.0 + i * sideGap, cy),
        sideDotR * (1.0 - i * 0.08),
        sidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotCirclePainter oldDelegate) => false;
}
