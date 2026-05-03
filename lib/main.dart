import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:brisconnect/firebase_options.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/screens/admin_dashboard_screen.dart';
import 'package:brisconnect/screens/local_portal_screen.dart';
import 'package:brisconnect/screens/visitor_portal_screen.dart';
import 'package:brisconnect/screens/admin_login_screen.dart';
import 'package:brisconnect/screens/welcome_screen.dart';
import 'package:brisconnect/services/app_display_settings_controller.dart';
import 'package:brisconnect/services/discover_data_service.dart';
import 'package:brisconnect/services/attraction_detail_service.dart';
import 'package:brisconnect/services/role_access_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/role_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shouldUseFlutterFireOptions = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  if (shouldUseFlutterFireOptions) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }
  debugPrint('[StorageDebug] bucket = ${FirebaseStorage.instance.bucket}');
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  _configureFirestoreTransport();

  // Enable offline persistence with unlimited cache so Firestore
  // survives transient network drops on the emulator and real devices.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  runApp(const BrisConnectApp());

  // Seed discover catalog in the background (no-op if already seeded).
  DiscoverDataService().ensureSeeded();

  // Pre-load attraction detail catalog from Firestore (seeds on first run).
  AttractionDetailService.init();
}

void _configureFirestoreTransport() {
  if (kIsWeb) {
    return;
  }

  const useEmulator = bool.fromEnvironment(
    'USE_FIRESTORE_EMULATOR',
    defaultValue: false,
  );
  if (!useEmulator) {
    return;
  }

  const emulatorPort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );
  final emulatorHost = defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';

  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, emulatorPort);
  debugPrint('[FirebaseProbe] Using Firestore emulator at $emulatorHost:$emulatorPort');
}

class BrisConnectApp extends StatefulWidget {
  const BrisConnectApp({super.key});

  @override
  State<BrisConnectApp> createState() => _BrisConnectAppState();
}

class _BrisConnectAppState extends State<BrisConnectApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-enable Firestore networking every time the app comes back to the
  /// foreground. This recovers from emulator network drops and device
  /// sleep/wake cycles automatically.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FirebaseFirestore.instance.enableNetwork().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppDisplaySettings>(
      valueListenable: AppDisplaySettingsController.settings,
      builder: (context, settings, _) {
        final baseTheme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppPalette.deepBlue,
            primary: AppPalette.ochre,
            secondary: AppPalette.gold,
            surface: AppPalette.surface,
          ),
          scaffoldBackgroundColor: AppPalette.background,
          cardColor: AppPalette.surface,
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: AppPalette.surface,
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.border.withValues(alpha: 0.4)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.ochre,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.ochre,
              side: const BorderSide(color: AppPalette.ochre),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.ochre,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: AppPalette.ochre.withValues(alpha: 0.12),
            selectedColor: AppPalette.ochre,
            labelStyle: const TextStyle(color: AppPalette.charcoal),
            secondaryLabelStyle: const TextStyle(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppPalette.background.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppPalette.border.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppPalette.ochre),
            ),
          ),
        );

        final darkTheme = ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppPalette.ochre,
            brightness: Brightness.dark,
            primary: AppPalette.ochre,
            secondary: AppPalette.gold,
            surface: const Color(0xFF1A1A1A),
          ),
          scaffoldBackgroundColor: Colors.black,
          cardColor: const Color(0xFF1A1A1A),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A1A),
            foregroundColor: AppPalette.ochre,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A1A1A),
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppPalette.ochre.withValues(alpha: 0.3)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.ochre,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.ochre,
              side: const BorderSide(color: AppPalette.ochre),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.ochre,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.black,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: AppPalette.ochre.withValues(alpha: 0.15),
            selectedColor: AppPalette.ochre,
            labelStyle: const TextStyle(color: AppPalette.ochre),
            secondaryLabelStyle: const TextStyle(color: Colors.black),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          iconTheme: const IconThemeData(color: AppPalette.ochre),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppPalette.ochre),
            bodyMedium: TextStyle(color: AppPalette.ochre),
            bodySmall: TextStyle(color: AppPalette.ochre),
            titleLarge: TextStyle(color: AppPalette.ochre, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(color: AppPalette.ochre, fontWeight: FontWeight.w600),
            titleSmall: TextStyle(color: AppPalette.ochre),
            labelLarge: TextStyle(color: AppPalette.ochre),
            labelMedium: TextStyle(color: AppPalette.ochre),
            labelSmall: TextStyle(color: AppPalette.ochre),
          ),
          dividerColor: AppPalette.ochre.withValues(alpha: 0.3),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            hintStyle: TextStyle(color: AppPalette.ochre.withValues(alpha: 0.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppPalette.ochre.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppPalette.ochre),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1A1A1A),
            selectedItemColor: AppPalette.ochre,
            unselectedItemColor: Color(0xFF666666),
          ),
          listTileTheme: const ListTileThemeData(
            textColor: AppPalette.ochre,
            iconColor: AppPalette.ochre,
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'BrisConnect',
          theme: baseTheme,
          darkTheme: darkTheme,
          themeMode:
              AppDisplaySettingsController.toThemeMode(settings.themePreference),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler:
                    TextScaler.linear(settings.textScaleFactor.clamp(0.9, 1.3)),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          routes: {
            '/admin/login': (_) => const AdminLoginScreen(),
            '/admin/dashboard': (_) => RoleGuard(
                  allowedRoles: {AppUserRole.admin},
                  deniedMessage:
                      'Access denied. Admin privileges are required.',
                  child: AdminDashboardScreen(),
                ),
            '/local/portal': (_) => const RoleGuard(
                  allowedRoles: {AppUserRole.local},
                  deniedMessage:
                      'Access denied. Local account access is required.',
                  child: LocalPortalScreen(),
                ),
            '/visitor/portal': (_) => const RoleGuard(
                  allowedRoles: {AppUserRole.visitor},
                  deniedMessage:
                      'Access denied. Visitor account access is required.',
                  child: VisitorPortalScreen(),
                ),
          },
          home: const _StartupProbeScreen(),
        );
      },
    );
  }
}

class _StartupProbeScreen extends StatefulWidget {
  const _StartupProbeScreen();

  @override
  State<_StartupProbeScreen> createState() => _StartupProbeScreenState();
}

class _StartupProbeScreenState extends State<_StartupProbeScreen> {
  bool _isRestoring = false;
  Future<_FirebaseProbeResult>? _probeFuture;

  @override
  void initState() {
    super.initState();
    _probeFuture = _probeFirebaseDatabase();
  }

  void _retryProbe() {
    setState(() {
      _probeFuture = _probeFirebaseDatabase();
    });
  }

  Future<_FirebaseProbeResult> _probeFirebaseDatabase({int attempt = 1}) async {
    try {
      await FirebaseFirestore.instance
          .collection('_connectivity_probe')
          .doc('startup')
          .get(const GetOptions(source: Source.server));

      debugPrint('[FirebaseProbe] Connected to Cloud Firestore.');

      return const _FirebaseProbeResult(
        status: _ProbeStatus.live,
        message: 'Connected to Firebase (Cloud Firestore).',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          '[FirebaseProbe] Connected to Firebase; Firestore denied access by rules.',
        );
        return const _FirebaseProbeResult(
          status: _ProbeStatus.live,
          message: 'Connected to Firebase (rules checked).',
        );
      }

      if (attempt < 3) {
        debugPrint('[FirebaseProbe] Attempt $attempt failed (${error.code}), retrying...');
        await Future.delayed(const Duration(seconds: 2));
        return _probeFirebaseDatabase(attempt: attempt + 1);
      }

      // Server unreachable — check whether local cache is available.
      return _tryCacheProbe();
    } catch (_) {
      if (attempt < 3) {
        debugPrint('[FirebaseProbe] Attempt $attempt failed (unknown), retrying...');
        await Future.delayed(const Duration(seconds: 2));
        return _probeFirebaseDatabase(attempt: attempt + 1);
      }

      return _tryCacheProbe();
    }
  }

  Future<_FirebaseProbeResult> _tryCacheProbe() async {
    try {
      await FirebaseFirestore.instance
          .collection('_connectivity_probe')
          .doc('startup')
          .get(const GetOptions(source: Source.cache));

      debugPrint('[FirebaseProbe] Server unreachable — using offline cache.');
      return const _FirebaseProbeResult(
        status: _ProbeStatus.offline,
        message:
            'No internet connection. Running in offline mode — cached data will be used.',
      );
    } catch (_) {
      // First launch with no cache: also offline but no cached data yet.
      debugPrint('[FirebaseProbe] Server unreachable — no local cache.');
      return const _FirebaseProbeResult(
        status: _ProbeStatus.offline,
        message:
            'No internet connection. Some features may be limited until connectivity is restored.',
      );
    }
  }

  Future<void> _continue() async {
    setState(() => _isRestoring = true);
    final role = await RoleAccessService.restoreAndResolveSession();
    if (!mounted) return;
    switch (role) {
      case AppUserRole.admin:
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
      case AppUserRole.local:
        Navigator.of(context).pushReplacementNamed('/local/portal');
      case AppUserRole.visitor:
        Navigator.of(context).pushReplacementNamed('/visitor/portal');
      default:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
    }
  }

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
                      const SizedBox(height: 14),
                      FutureBuilder<_FirebaseProbeResult>(
                        future: _probeFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Checking Firebase connection (may retry up to 3×)...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppPalette.mutedText,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final result = snapshot.data ??
                              const _FirebaseProbeResult(
                                status: _ProbeStatus.failed,
                                message:
                                    'Unable to determine Firebase connection status.',
                              );

                          final Color bgColor = switch (result.status) {
                            _ProbeStatus.live    => Colors.green.withValues(alpha: 0.08),
                            _ProbeStatus.offline => Colors.orange.withValues(alpha: 0.08),
                            _ProbeStatus.failed  => Colors.red.withValues(alpha: 0.08),
                          };
                          final Color borderColor = switch (result.status) {
                            _ProbeStatus.live    => Colors.green.withValues(alpha: 0.5),
                            _ProbeStatus.offline => Colors.orange.withValues(alpha: 0.5),
                            _ProbeStatus.failed  => Colors.red.withValues(alpha: 0.5),
                          };
                          final Color iconColor = switch (result.status) {
                            _ProbeStatus.live    => Colors.green.shade700,
                            _ProbeStatus.offline => Colors.orange.shade700,
                            _ProbeStatus.failed  => Colors.red.shade700,
                          };
                          final Color textColor = switch (result.status) {
                            _ProbeStatus.live    => Colors.green.shade800,
                            _ProbeStatus.offline => Colors.orange.shade800,
                            _ProbeStatus.failed  => Colors.red.shade800,
                          };
                          final IconData icon = switch (result.status) {
                            _ProbeStatus.live    => Icons.check_circle,
                            _ProbeStatus.offline => Icons.wifi_off_rounded,
                            _ProbeStatus.failed  => Icons.error,
                          };

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 18, color: iconColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    result.message,
                                    style: TextStyle(fontSize: 13, color: textColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (result.status != _ProbeStatus.live) ...[  
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _retryProbe,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry Connection'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: result.status == _ProbeStatus.offline
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
                                side: BorderSide(
                                  color: result.status == _ProbeStatus.offline
                                      ? Colors.orange.shade300
                                      : Colors.red.shade300,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isRestoring ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.ochre,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isRestoring
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Continue To App'),
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

class _FirebaseProbeResult {
  final _ProbeStatus status;
  final String message;

  // Kept for backward-compat with the FutureBuilder null fallback.
  bool get connected => status == _ProbeStatus.live;

  const _FirebaseProbeResult({
    required this.status,
    required this.message,
  });
}

enum _ProbeStatus { live, offline, failed }
