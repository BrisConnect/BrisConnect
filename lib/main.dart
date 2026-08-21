import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;
import 'l10n/app_localizations.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:brisconnect/screens/home_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/screens/splash_screen.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';
import 'package:brisconnect/screens/local_portal_screen.dart';
import 'package:brisconnect/screens/admin_business_management_screen.dart';
import 'package:brisconnect/screens/admin_community_feed_screen.dart';
import 'package:brisconnect/screens/admin_dashboard_screen.dart';
import 'package:brisconnect/screens/admin_google_listings_screen.dart';
import 'package:brisconnect/screens/admin_notifications_screen.dart';
import 'package:brisconnect/screens/admin_promotion_management_screen.dart';
import 'package:brisconnect/screens/admin_reported_events_screen.dart';
import 'package:brisconnect/screens/admin_reported_reviews_screen.dart';
import 'package:brisconnect/screens/admin_reports_hub_screen.dart';
import 'package:brisconnect/screens/admin_subscription_management_screen.dart';
import 'package:brisconnect/screens/admin_user_management_screen.dart';
import 'package:brisconnect/screens/business_profile_form_screen.dart';
import 'package:brisconnect/screens/visitor_push_notifications_screen.dart';
import 'package:brisconnect/screens/owner_notifications_screen.dart';
import 'package:brisconnect/screens/business_profile_view_screen.dart';
import 'package:brisconnect/screens/menu_management_screen.dart';
import 'package:brisconnect/screens/notification_health_screen.dart';
import 'package:brisconnect/screens/privacy_policy_screen.dart';
import 'package:brisconnect/screens/promotion_detail_screen.dart';
import 'package:brisconnect/screens/terms_of_service_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/screens/food_detail_screen.dart';
import 'package:brisconnect/screens/visitor_event_detail_screen.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/food_business.dart';
import 'package:brisconnect/services/food_business_service.dart';
import 'package:brisconnect/services/fcm_service.dart';
import 'package:brisconnect/services/app_display_settings_controller.dart';
import 'package:brisconnect/services/role_access_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs on the web so deep links such as
  // /local/portal?checkout=success work after external redirects
  // (e.g. returning from Stripe Checkout). Firebase Hosting rewrites
  // all paths to index.html, so this is safe to enable.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Restore the signed-in user's session before initializing FCM so tokens
    // are written to the correct collection (visitor_users vs local_users).
    //
    // This prevents RoleGuard from incorrectly redirecting to the welcome
    // screen while Firebase Auth is still restoring after a page refresh or
    // an external redirect (e.g. returning from Stripe Checkout).
    //
    // Wait up to 10 seconds: on some browsers the cached auth token is only
    // restored after IndexedDB opens, which can be delayed after a cross-site
    // redirect.
    fb_auth.User? restoredUser;
    try {
      restoredUser = await fb_auth.FirebaseAuth.instance
          .authStateChanges()
          .where((u) => u != null)
          .first
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // No cached user; app will continue to welcome/login flow.
    }
    // Attempt to restore the in-memory role, but do NOT sign out if it fails.
    // RoleGuard will retry and, if necessary, redirect to the correct login
    // screen rather than silently logging the user out.
    await RoleAccessService.restoreAndResolveSession(restoredUser);

    // Initialize FCM after the role is known so tokens land in the right
    // Firestore collection used by the visitor/local Cloud Functions.
    await FcmService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const BrisConnectApp());
}

class BrisConnectApp extends StatefulWidget {
  const BrisConnectApp({super.key});

  static BrisConnectAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<BrisConnectAppState>();

  @override
  State<BrisConnectApp> createState() => BrisConnectAppState();
}

class BrisConnectAppState extends State<BrisConnectApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  void initState() {
    super.initState();
    // Listen to locale changes so the entire app rebuilds when language preference changes
    localeChangeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (!mounted) return;
    setState(() {
      // Trigger rebuild of MaterialApp and all descendants
    });
  }

  @override
  void dispose() {
    localeChangeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BrisConnect+',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('zh'),
        Locale('ar'),
        Locale('hi'),
        Locale('it'),
        Locale('ja'),
        Locale('ko'),
        Locale('pt'),
        Locale('ru'),
        Locale('vi'),
        Locale('el'),
        Locale('pa'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppPalette.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppPalette.background,
          foregroundColor: AppPalette.charcoal,
          elevation: 0,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppPalette.charcoal),
          bodyMedium: TextStyle(color: AppPalette.charcoal),
          bodySmall: TextStyle(color: AppPalette.mutedText),
        ),
      ),
      // On the web, read the actual browser path so deep links such as
      // /local/portal survive a page refresh. On mobile we always start at
      // the splash screen.
      initialRoute: kIsWeb ? Uri.base.path : '/',
      onGenerateRoute: (settings) {
        // Strip query parameters so deep-link returns from Stripe
        // (e.g. /local/portal?checkout=cancel) match the route definitions.
        final routePath = Uri.parse(settings.name ?? '/').path;

        switch (routePath) {
          case '/':
          case '/index.html':
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
              settings: settings,
            );
          case '/visitor/portal':
            return MaterialPageRoute(
              builder: (_) => VisitorPortalScreen(
                key: VisitorPortalScreen.globalKey,
              ),
              settings: settings,
            );
          case '/visitor/notifications':
            return MaterialPageRoute(
              builder: (_) => const VisitorPushNotificationsScreen(),
              settings: settings,
            );
          case '/local/notifications':
            return MaterialPageRoute(
              builder: (_) => const OwnerNotificationsScreen(),
              settings: settings,
            );
          case '/local/portal':
            final query = Uri.parse(settings.name ?? '/').queryParameters;
            final checkout = query['checkout'];
            final sessionId = query['session_id'];
            final portal = query['portal'];
            final args = settings.arguments;
            final initialTabIndex =
                args is Map ? (args['initialTabIndex'] as int? ?? 0) : 0;
            return MaterialPageRoute(
              builder: (_) => LocalPortalScreen(
                checkoutStatus: checkout,
                checkoutSessionId: sessionId,
                portalStatus: portal,
                initialTabIndex: initialTabIndex,
              ),
              settings: settings,
            );
          case '/admin/dashboard':
            return MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(),
              settings: settings,
            );
          case '/admin/google-listings':
            return MaterialPageRoute(
              builder: (_) => const AdminGoogleListingsScreen(),
              settings: settings,
            );
          case '/admin/businesses':
            return MaterialPageRoute(
              builder: (_) => AdminBusinessManagementScreen(),
              settings: settings,
            );
          case '/admin/notifications':
            return MaterialPageRoute(
              builder: (_) => const AdminNotificationsScreen(),
              settings: settings,
            );
          case '/admin/reports':
            return MaterialPageRoute(
              builder: (_) => const AdminReportsHubScreen(),
              settings: settings,
            );
          case '/admin/reported-events':
            return MaterialPageRoute(
              builder: (_) => AdminReportedEventsScreen(),
              settings: settings,
            );
          case '/admin/reported-reviews':
            return MaterialPageRoute(
              builder: (_) => AdminReportedReviewsScreen(),
              settings: settings,
            );
          case '/admin/subscriptions':
            return MaterialPageRoute(
              builder: (_) => AdminSubscriptionManagementScreen(),
              settings: settings,
            );
          case '/admin/promotions':
            return MaterialPageRoute(
              builder: (_) => AdminPromotionManagementScreen(),
              settings: settings,
            );
          case '/admin/users':
            return MaterialPageRoute(
              builder: (_) => AdminUserManagementScreen(),
              settings: settings,
            );
          case '/admin/community':
            return MaterialPageRoute(
              builder: (_) => const AdminCommunityFeedScreen(),
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
          case '/business/menu':
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
              builder: (_) => MenuManagementScreen(business: business),
              settings: settings,
            );
          case '/promotion/detail':
            final promotionId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => PromotionDetailScreen(promotionId: promotionId),
              settings: settings,
            );
          case '/notification-health':
            return MaterialPageRoute(
              builder: (_) => const NotificationHealthScreen(),
              settings: settings,
            );
          case '/privacy-policy':
            return MaterialPageRoute(
              builder: (_) => const PrivacyPolicyScreen(),
              settings: settings,
            );
          case '/terms-of-service':
            return MaterialPageRoute(
              builder: (_) => const TermsOfServiceScreen(),
              settings: settings,
            );
          case '/welcome':
            return MaterialPageRoute(
              builder: (_) => const AnimatedWelcomeScreen(),
              settings: settings,
            );
          default:
            // Support deep links such as /food/<id> and /event/<id> that are
            // shared via QR codes and social apps. Try to resolve the entity
            // and open the correct detail screen; otherwise fall through to
            // the 404 page.
            if (routePath.startsWith('/business/')) {
              final id = routePath.substring('/business/'.length).trim();
              if (id.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => BusinessProfileViewScreen(businessId: id),
                  settings: settings,
                );
              }
            }
            if (routePath.startsWith('/food/')) {
              final id = routePath.substring('/food/'.length).trim();
              if (id.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => _FoodDetailLoader(businessId: id),
                  settings: settings,
                );
              }
            }
            if (routePath.startsWith('/event/')) {
              final id = routePath.substring('/event/'.length).trim();
              if (id.isNotEmpty) {
                return MaterialPageRoute(
                  builder: (_) => _EventDetailLoader(eventId: id),
                  settings: settings,
                );
              }
            }
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

/// Loads a food/business profile by ID and opens the appropriate detail screen.
class _FoodDetailLoader extends StatelessWidget {
  final String businessId;

  const _FoodDetailLoader({required this.businessId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FoodBusiness?>(
      future: FoodBusinessService().getBusinessById(businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final food = snapshot.data;
        if (food == null) {
          return const Scaffold(
            body: Center(child: Text('Food spot not found')),
          );
        }
        return FoodDetailScreen(
          id: food.id,
          title: food.name,
          description: food.description,
          location: food.address,
          cuisine: food.cuisineTypes?.isNotEmpty == true
              ? food.cuisineTypes!.first
              : 'Food',
          imageUrl: food.imageUrl ?? '',
          categories: food.cuisineTypes ?? const [],
          rating: food.averageRating,
          badge: 'Food',
          dateTime: '',
          price: '',
          mapQuery: food.address,
          webLink: food.website ?? '',
          phone: food.phone ?? '',
          email: food.email ?? '',
          openingHours: food.operatingHours ?? '',
          facebookUrl: food.facebookUrl ?? '',
          instagramUrl: food.instagramUrl ?? '',
          onlineOrderUrl: food.onlineOrderUrl ?? '',
          aiAudio: '',
          isGoogleListing: food.isGoogleListing,
        );
      },
    );
  }
}

/// Loads an event by ID and opens the event detail screen.
class _EventDetailLoader extends StatelessWidget {
  final String eventId;

  const _EventDetailLoader({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchEvent(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final event = snapshot.data;
        if (event == null) {
          return const Scaffold(
            body: Center(child: Text('Event not found')),
          );
        }
        return VisitorEventDetailScreen(event: event);
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchEvent(String id) async {
    final collections = ['events', 'business_events'];
    for (final collection in collections) {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(id)
          .get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
    }
    return null;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      debugPrint('Selected account type: $displayType');
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
              content:
                  Text('Biometric authentication not available on this device'),
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
      backgroundColor: AppPalette.background,
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
                    AppPalette.background,
                    AppPalette.surface,
                    AppPalette.background,
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
                      const Color(0xFF007BFF).withValues(alpha: 0.15),
                      const Color(0xFF007BFF).withValues(alpha: 0.0),
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
                      const Color(0xFFFF7A1A).withValues(alpha: 0.1),
                      const Color(0xFFFF7A1A).withValues(alpha: 0.0),
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
                            color:
                                const Color(0xFF007BFF).withValues(alpha: 0.3),
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
                              color: const Color(0xFF11162B)
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF007BFF)
                                    .withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
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
                                    'Welcome back! Please sign in to continue.',
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
                                        color: const Color(0xFF007BFF)
                                            .withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: DropdownButtonFormField<String>(
                                      initialValue: selectedAccountType,
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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
                                        setState(
                                            () => selectedAccountType = value);
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
                                          color: const Color(0xFFFF7A1A)
                                              .withValues(alpha: 0.3),
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
                                          color: const Color(0xFF007BFF)
                                              .withValues(alpha: 0.4),
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
                                              decoration:
                                                  TextDecoration.underline,
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
