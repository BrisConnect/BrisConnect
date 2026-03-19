import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/screens/admin_dashboard_screen.dart';
import 'package:brisconnect/screens/admin_login_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';

void main() {
  runApp(const BrisConnectApp());
}

class BrisConnectApp extends StatelessWidget {
  const BrisConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BrisConnect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.deepBlue,
          primary: AppPalette.ochre,
          secondary: AppPalette.gold,
          surface: AppPalette.surface,
        ),
        scaffoldBackgroundColor: AppPalette.background,
        cardColor: AppPalette.surface,
        useMaterial3: true,
      ),
      routes: {
        '/admin/login': (_) => const AdminLoginScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/admin/dashboard') {
          if (!AdminAuth.isAdminLoggedIn) {
            return MaterialPageRoute(
              builder: (_) => const AdminLoginScreen(),
              settings: const RouteSettings(name: '/admin/login'),
            );
          }

          return MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen(),
            settings: settings,
          );
        }

        return null;
      },
      home: const _StartupProbeScreen(),
    );
  }
}

class _StartupProbeScreen extends StatelessWidget {
  const _StartupProbeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppPalette.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppPalette.cardShadow,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppPalette.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.visibility_rounded,
                          color: AppPalette.deepBlue,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Startup Probe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.charcoal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'If you can see this screen, the emulator is rendering Flutter correctly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppPalette.mutedText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const WelcomeScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.ochre,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Continue To App'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}