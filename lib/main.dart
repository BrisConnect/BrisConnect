import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:local_auth/local_auth.dart';
import 'package:brisconnect/screens/home_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';
import 'package:brisconnect/screens/local_portal_screen.dart';
import 'package:brisconnect/screens/admin_dashboard_screen.dart';
import 'package:brisconnect/screens/business_profile_form_screen.dart';
import 'package:brisconnect/screens/business_profile_view_screen.dart';
import 'package:brisconnect/models/business.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const BrisConnectApp());
}

class BrisConnectApp extends StatelessWidget {
  const BrisConnectApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrisConnect+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07132E),
      ),
      home: const AnimatedWelcomeScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/visitor/portal':
            return MaterialPageRoute(
              builder: (_) => const VisitorPortalScreen(),
              settings: settings,
            );
          case '/local/portal':
            return MaterialPageRoute(
              builder: (_) => const LocalPortalScreen(),
              settings: settings,
            );
          case '/admin/dashboard':
            return MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(),
              settings: settings,
            );
          case '/business/create':
            final userId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => BusinessProfileFormScreen(userId: userId),
              settings: settings,
            );
          case '/business/view':
            final businessId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => BusinessProfileViewScreen(
                businessId: businessId,
                isOwnProfile: false,
              ),
              settings: settings,
            );
          case '/business/edit':
            final business = settings.arguments as Business?;
            if (business == null) {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('No business provided')),
                ),
                settings: settings,
              );
            }
            return MaterialPageRoute(
              builder: (_) => BusinessProfileFormScreen(
                userId: business.ownerId,
                existingBusiness: business,
              ),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Page not found')),
              ),
              settings: settings,
            );
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? selectedAccountType;
  int _tapCount = 0;
  List<String> accountTypes = ['Visitor', 'Local'];

  @override
  void initState() {
    super.initState();
  }

  void _updateAccountTypes() {
    if (_tapCount >= 5) {
      accountTypes = [
        'Visitor',
        'Local',
        'Admin',
      ];
    } else {
      accountTypes = [
        'Visitor',
        'Local',
      ];
    }
  }

  void _onScreenTap() {
    setState(() {
      _tapCount++;
      _updateAccountTypes();
      if (_tapCount == 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔓 Admin unlocked!'),
            backgroundColor: Color(0xFFFF7A1A),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  void _handleContinue() {
    if (selectedAccountType != null) {
      final displayType = selectedAccountType!.trim();
      print('Selected account type: $displayType');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account type'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleBiometricLogin() async {
    try {
      final LocalAuthentication auth = LocalAuthentication();
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;

      if (!canAuthenticateWithBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication not available on this device'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access BrisConnect',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate && mounted) {
        // Navigate to home screen on successful authentication
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07132E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFFFF7A1A),
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: _onScreenTap,
        child: Stack(
          children: [
            // Animated gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF07132E),
                    const Color(0xFF0F1B3E),
                    const Color(0xFF07132E),
                  ],
                ),
              ),
            ),

          // Subtle futuristic glow effects
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF007BFF).withOpacity(0.15),
                    const Color(0xFF007BFF).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF7A1A).withOpacity(0.1),
                    const Color(0xFFFF7A1A).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007BFF).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/brisconnect_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF11162B),
                              child: const Center(
                                child: Icon(
                                  Icons.location_city,
                                  size: 60,
                                  color: Color(0xFF007BFF),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App name
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: const [Color(0xFF007BFF), Color(0xFFFF7A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'BrisConnect+',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    const Text(
                      'Connect. Collaborate. Thrive.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF9BA9C7),
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Login card with glassmorphism effect
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF11162B).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF007BFF).withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Title
                                  const Text(
                                    'Log In',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF5F7FF),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Subtitle
                                  const Text(
                                    'Welcome back\! Please sign in to continue.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF9BA9C7),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Account type dropdown
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF007BFF).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      value: selectedAccountType,
                                      hint: const Text(
                                        'Choose account type',
                                        style: TextStyle(
                                          color: Color(0xFF9BA9C7),
                                        ),
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF007BFF),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                      items: accountTypes.map((type) {
                                        return DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => selectedAccountType = value);
                                      },
                                      style: const TextStyle(
                                        color: Color(0xFFF5F7FF),
                                        fontSize: 14,
                                      ),
                                      dropdownColor: const Color(0xFF11162B),
                                      isExpanded: true,
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Continue button with gradient
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF7A1A),
                                          Color(0xFF007BFF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF7A1A).withOpacity(0.3),
                                          blurRadius: 12,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _handleContinue,
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 24,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Continue',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Biometric sign-in option
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF007BFF).withOpacity(0.4),
                                          width: 2,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleBiometricLogin,
                                          customBorder: const CircleBorder(),
                                          child: const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Icon(
                                              Icons.fingerprint,
                                              size: 32,
                                              color: Color(0xFF007BFF),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Sign up text
                                  Center(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: "Don't have an account? ",
                                            style: TextStyle(
                                              color: Color(0xFF9BA9C7),
                                              fontSize: 14,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Sign up',
                                            style: const TextStyle(
                                              color: Color(0xFFFF7A1A),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                            recognizer: null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
