import 'dart:async';

import 'package:flutter/material.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/screens/onboarding_screen.dart';
import 'package:brisconnect/services/intro_settings_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Animated splash screen shown on every app/website launch.
///
/// After the animation completes it checks whether the user has seen the
/// onboarding slides. First-time users see [OnboardingScreen]; returning users
/// see [AnimatedWelcomeScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    // Do not redirect away from deep-link routes such as /terms-of-service,
    // /privacy-policy, or the business/visitor/admin portals. On the web the
    // initial route can be reported as '/' even when the browser URL is a
    // deep link (e.g. /local/portal), so we also check the actual browser path.
    final routeName = ModalRoute.of(context)?.settings.name;
    final browserPath = Uri.base.path;
    if ((routeName != null &&
            routeName != '/' &&
            routeName != '/index.html' &&
            routeName.isNotEmpty) ||
        (browserPath != '/' &&
            browserPath != '/index.html' &&
            browserPath.isNotEmpty)) {
      return;
    }

    final onboardingSeen = await IntroSettingsService.hasSeenOnboarding();
    if (!mounted) return;

    if (onboardingSeen) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3F),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/Brisconnect New.jpg',
                height: 140,
              ),
              const SizedBox(height: 24),
              const Text(
                'BrisConnect+',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Discover Brisbane\'s best local food',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.ochre,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
