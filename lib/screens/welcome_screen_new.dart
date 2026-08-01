import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/local_login_screen.dart';
import 'package:brisconnect/screens/privacy_policy_screen.dart';
import 'package:brisconnect/screens/terms_of_service_screen.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';
import 'package:brisconnect/services/email_code_auth_service.dart';
import 'package:brisconnect/services/phone_auth_service.dart';
import 'package:brisconnect/utils/phone_validation.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';

// Premium dark navy theme.
const _background = Color(0xFF081B4B);
const _backgroundGradientTop = Color(0xFF0C235E);
const _backgroundGradientBottom = Color(0xFF06153A);
const _cardDark = Color(0xFF10255C);
const _cardBorder = Color(0xFF1E3A7A);
const _accentOrange = Color(0xFFFF7A00);
const _white = Colors.white;
const _white70 = Color(0xFFB3C1E0);
const _white50 = Color(0xFF8090B8);

class AnimatedWelcomeScreen extends StatefulWidget {
  const AnimatedWelcomeScreen({super.key});

  @override
  State<AnimatedWelcomeScreen> createState() => _AnimatedWelcomeScreenState();
}

class _AnimatedWelcomeScreenState extends State<AnimatedWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _cardController;
  late AudioPlayer _audioPlayer;
  bool _soundPlayed = false;

  int _adminTapCount = 0;

  bool _visitorOpen = false;
  bool _businessOpen = false;
  bool _signUpOpen = false;

  final _visitorEmailController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _codeController = TextEditingController();
  final _visitorFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();

  bool _visitorSending = false;
  bool _businessSending = false;
  bool _isVerifying = false;
  String? _visitorStatus;
  String? _businessStatus;
  InlineStatusType _visitorStatusType = InlineStatusType.error;
  InlineStatusType _businessStatusType = InlineStatusType.error;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _audioPlayer = AudioPlayer();

    Future.delayed(const Duration(milliseconds: 200), () {
      _logoController.forward();
      _playWelcomeSound();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _cardController.forward();
    });
  }

  Future<void> _playWelcomeSound() async {
    if (_soundPlayed) return;
    _soundPlayed = true;

    if (kIsWeb) {
      debugPrint('Welcome sound skipped on web');
      return;
    }

    try {
      await _audioPlayer.setAsset('assets/sounds/welcome.mp3').catchError((_) {
        debugPrint('Welcome sound not found, continuing without sound');
        return Duration.zero;
      });
      _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _navigateAsGuest() {
    Navigator.of(context).pushReplacementNamed('/visitor/portal');
  }

  void _onLogoTap() {
    _adminTapCount++;
    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _showAdminLogin();
    }
  }

  void _showAdminLogin() {
    showDialog(
      context: context,
      builder: (context) => const _AdminLoginDialog(),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _cardController.dispose();
    _audioPlayer.dispose();
    _visitorEmailController.dispose();
    _businessEmailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _toggleVisitor() {
    setState(() {
      _visitorOpen = !_visitorOpen;
      _visitorStatus = null;
    });
  }

  void _toggleBusiness() {
    setState(() {
      _businessOpen = !_businessOpen;
      _businessStatus = null;
    });
  }

  void _toggleSignUp() {
    setState(() {
      _signUpOpen = !_signUpOpen;
    });
  }

  void _showSignUpDialog(String role) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignUpDialog(role: role),
    );
  }

  Future<void> _sendCode(String userType) async {
    final isVisitor = userType == 'visitor';
    final formKey = isVisitor ? _visitorFormKey : _businessFormKey;
    final emailController =
        isVisitor ? _visitorEmailController : _businessEmailController;

    if (!formKey.currentState!.validate()) return;

    setState(() {
      if (isVisitor) {
        _visitorSending = true;
        _visitorStatus = null;
      } else {
        _businessSending = true;
        _businessStatus = null;
      }
    });

    final result = await EmailCodeAuthService.sendCode(
      email: emailController.text,
      userType: userType,
    );

    if (!mounted) return;
    setState(() {
      if (isVisitor) {
        _visitorSending = false;
      } else {
        _businessSending = false;
      }
    });

    switch (result) {
      case SendCodeResult.sent:
        _showCodeDialog(userType);
      case SendCodeResult.invalidEmail:
        setState(() {
          if (isVisitor) {
            _visitorStatus = EmailCodeAuthService.lastErrorMessage;
            _visitorStatusType = InlineStatusType.error;
          } else {
            _businessStatus = EmailCodeAuthService.lastErrorMessage;
            _businessStatusType = InlineStatusType.error;
          }
        });
      case SendCodeResult.tooManyRequests:
        setState(() {
          final message = EmailCodeAuthService.lastErrorMessage ??
              'Please wait before requesting another code.';
          if (isVisitor) {
            _visitorStatus = message;
            _visitorStatusType = InlineStatusType.info;
          } else {
            _businessStatus = message;
            _businessStatusType = InlineStatusType.info;
          }
        });
      case SendCodeResult.networkError:
      case SendCodeResult.unknownError:
        setState(() {
          final message = EmailCodeAuthService.lastErrorMessage ??
              'Could not send code. Please try again.';
          if (isVisitor) {
            _visitorStatus = message;
            _visitorStatusType = InlineStatusType.error;
          } else {
            _businessStatus = message;
            _businessStatusType = InlineStatusType.error;
          }
        });
    }
  }

  Future<void> _verifyCode(String userType) async {
    final isVisitor = userType == 'visitor';
    final emailController =
        isVisitor ? _visitorEmailController : _businessEmailController;

    setState(() {
      _isVerifying = true;
      if (isVisitor) {
        _visitorStatus = null;
      } else {
        _businessStatus = null;
      }
    });

    final email = emailController.text.trim();
    final code = _codeController.text.trim();
    final ok = isVisitor
        ? await VisitorAuth.login(email: email, code: code)
        : await LocalAuth.login(email: email, code: code);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (!ok) {
      setState(() {
        final message = isVisitor
            ? VisitorAuth.lastErrorMessage
            : LocalAuth.lastErrorMessage;
        if (isVisitor) {
          _visitorStatus = message;
          _visitorStatusType = InlineStatusType.error;
        } else {
          _businessStatus = message;
          _businessStatusType = InlineStatusType.error;
        }
      });
      return;
    }

    if (mounted) {
      _routeByRole(userType);
    }
  }

  void _routeByRole(String role) {
    switch (role) {
      case 'local':
        Navigator.of(context).pushReplacementNamed('/local/portal');
      case 'visitor':
      default:
        Navigator.of(context).pushReplacementNamed('/visitor/portal');
    }
  }

  void _showCodeDialog(String userType) {
    final isVisitor = userType == 'visitor';
    final emailController =
        isVisitor ? _visitorEmailController : _businessEmailController;

    _codeController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final status = isVisitor ? _visitorStatus : _businessStatus;
          final statusType =
              isVisitor ? _visitorStatusType : _businessStatusType;

          return AlertDialog(
            backgroundColor: _cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: _cardBorder.withValues(alpha: 0.6)),
            ),
            title: const Text(
              'Enter Sign-In Code',
              style: TextStyle(color: _white, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A code has been sent to ${emailController.text}',
                  style: const TextStyle(color: _white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _white,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: _white50.withValues(alpha: 0.5),
                      fontSize: 24,
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: _background.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: _accentOrange, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 12),
                  InlineStatusMessage(
                    message: status,
                    type: statusType,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _white70),
                ),
              ),
              ElevatedButton(
                onPressed: _isVerifying
                    ? null
                    : () async {
                        await _verifyCode(userType);
                        setDialogState(() {});
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: _white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _white,
                        ),
                      )
                    : const Text('Sign In'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;
    final horizontalPadding = size.width < 600 ? 24.0 : 48.0;

    return Scaffold(
      backgroundColor: _background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundGradientTop,
              _background,
              _backgroundGradientBottom
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // macOS (and other desktop platforms) can pass zero-size
              // constraints during the initial window frame. Skip layout
              // until we have real dimensions to avoid assertion cascades
              // from hit-testing widgets that have not been laid out.
              if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                return const SizedBox.shrink();
              }

              final maxCardWidth =
                  constraints.maxWidth - (horizontalPadding * 2);
              final cardWidth = (maxCardWidth < 380 ? maxCardWidth : 520)
                  .toDouble()
                  .clamp(320.0, maxCardWidth);

              // Use a Column instead of Stack/Positioned so the card
              // renders predictably on Safari and other web browsers.
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: cardWidth,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: _cardDark,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: _cardBorder.withValues(alpha: 0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),

                              // Logo with hidden admin tap
                              FadeTransition(
                                opacity: _logoController,
                                child: GestureDetector(
                                  onTap: _onLogoTap,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: isSmall ? 110 : 130,
                                        height: isSmall ? 110 : 130,
                                        decoration: BoxDecoration(
                                          color: _cardDark,
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                              color: _cardBorder, width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _accentOrange.withValues(
                                                  alpha: 0.15),
                                              blurRadius: 30,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          child: Image.asset(
                                            'assets/images/brisconnect_logo.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'BrisConnect+',
                                        style: TextStyle(
                                          fontSize: isSmall ? 30 : 36,
                                          fontWeight: FontWeight.w800,
                                          color: _white,
                                          letterSpacing: -0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Discover Brisbane's Best Local Food",
                                        style: TextStyle(
                                          fontSize: isSmall ? 14 : 16,
                                          fontWeight: FontWeight.w500,
                                          color: _white70,
                                          letterSpacing: 0.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Visitor sign in dropdown
                              FadeTransition(
                                opacity: _cardController,
                                child: _buildLoginDropdown(
                                  title: 'Visitor Sign In',
                                  icon: Icons.person_outline_rounded,
                                  isOpen: _visitorOpen,
                                  onToggle: _toggleVisitor,
                                  userType: 'visitor',
                                  formKey: _visitorFormKey,
                                  emailController: _visitorEmailController,
                                  isSending: _visitorSending,
                                  status: _visitorStatus,
                                  statusType: _visitorStatusType,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Business owner sign in dropdown
                              FadeTransition(
                                opacity: _cardController,
                                child: _buildLoginDropdown(
                                  title: 'Business Owner Sign In',
                                  icon: Icons.storefront_outlined,
                                  isOpen: _businessOpen,
                                  onToggle: _toggleBusiness,
                                  userType: 'local',
                                  formKey: _businessFormKey,
                                  emailController: _businessEmailController,
                                  isSending: _businessSending,
                                  status: _businessStatus,
                                  statusType: _businessStatusType,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Sign Up section
                              FadeTransition(
                                opacity: _cardController,
                                child: _buildSignUpSection(),
                              ),

                              const SizedBox(height: 12),

                              // Guest button
                              FadeTransition(
                                opacity: _cardController,
                                child: _buildGuestButton(),
                              ),

                              const SizedBox(height: 12),

                              // Acknowledgment of Country
                              FadeTransition(
                                opacity: _cardController,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'BrisConnect+ acknowledges the Traditional Custodians '
                                    'of the land on which Brisbane stands, and pays respects '
                                    'to Elders past, present and emerging.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: _white50,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _white.withValues(alpha: 0.25)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _white,
                decoration: TextDecoration.underline,
                decorationColor: _white70,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(fontSize: 13, color: _white50),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TermsOfServiceScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _white,
                decoration: TextDecoration.underline,
                decorationColor: _white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _navigateAsGuest,
        icon: const Icon(Icons.explore_outlined, color: _white70, size: 20),
        label: const Text(
          'Explore as Guest',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _white,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide(color: _white.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSignUpSection() {
    return Container(
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggleSignUp,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.person_add_outlined,
                      color: _accentOrange, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _signUpOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRoleOption(
                    icon: Icons.person_outline_rounded,
                    label: 'Visitor',
                    subtitle: 'Explore food, events and save favourites',
                    onTap: () => _showSignUpDialog('visitor'),
                  ),
                  const SizedBox(height: 10),
                  _buildRoleOption(
                    icon: Icons.storefront_outlined,
                    label: 'Business Owner',
                    subtitle: 'List your business and manage promotions',
                    onTap: () => _showSignUpDialog('local'),
                  ),
                ],
              ),
            ),
            crossFadeState: _signUpOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _accentOrange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _white70),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginDropdown({
    required String title,
    required IconData icon,
    required bool isOpen,
    required VoidCallback onToggle,
    required String userType,
    required GlobalKey<FormState> formKey,
    required TextEditingController emailController,
    required bool isSending,
    required String? status,
    required InlineStatusType statusType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: _accentOrange, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: _white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Email address',
                        hintStyle:
                            TextStyle(color: _white50.withValues(alpha: 0.8)),
                        filled: true,
                        fillColor: _background.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: _accentOrange, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) {
                          return 'Please enter your email address.';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 10),
                      InlineStatusMessage(
                        message: status,
                        type: statusType,
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: isSending ? null : () => _sendCode(userType),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentOrange,
                          foregroundColor: _white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _white,
                                ),
                              )
                            : const Text(
                                'Send Code',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _BusinessOwnerSheet extends StatefulWidget {
  const _BusinessOwnerSheet();

  @override
  State<_BusinessOwnerSheet> createState() => _BusinessOwnerSheetState();
}

class _BusinessOwnerSheetState extends State<_BusinessOwnerSheet> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _message;
  InlineStatusType _messageType = InlineStatusType.error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await EmailCodeAuthService.sendCode(
      email: _emailController.text,
      userType: 'local',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case SendCodeResult.sent:
        setState(() {
          _codeSent = true;
          _message = 'Code sent! Check your email.';
          _messageType = InlineStatusType.success;
        });
      default:
        setState(() {
          _message =
              EmailCodeAuthService.lastErrorMessage ?? 'Could not send code.';
          _messageType = InlineStatusType.error;
        });
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final ok = await LocalAuth.login(
      email: _emailController.text,
      code: _codeController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) {
      setState(() {
        _message = LocalAuth.lastErrorMessage ?? 'Invalid code.';
        _messageType = InlineStatusType.error;
      });
      return;
    }

    Navigator.of(context).pushReplacementNamed('/local/portal');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _white50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Business Owner Sign In',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your business email to receive a sign-in code.',
              style: TextStyle(fontSize: 14, color: _white70),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading && !_codeSent,
              style: const TextStyle(color: _white),
              decoration: _sheetInputDecoration('Business email'),
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) return 'Please enter your email.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Please enter a valid email.';
                }
                return null;
              },
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                style: const TextStyle(color: _white, letterSpacing: 6),
                decoration: _sheetInputDecoration('Enter code'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return 'Enter the code.';
                  return null;
                },
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              InlineStatusMessage(message: _message!, type: _messageType),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : (_codeSent ? _verify : _sendCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: _white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: _white, strokeWidth: 2.5),
                      )
                    : Text(_codeSent ? 'Verify & Sign In' : 'Send Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _sheetInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _white50.withValues(alpha: 0.7)),
      filled: true,
      fillColor: _background.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cardBorder.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentOrange, width: 2),
      ),
    );
  }
}

class _SignUpDialog extends StatefulWidget {
  const _SignUpDialog({required this.role});

  final String role;

  @override
  State<_SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<_SignUpDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _toE164Au(String value) {
    return PhoneValidation.toE164Au(value) ?? '';
  }

  Future<void> _startPhoneVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _toE164Au(_phoneController.text);
    final result = await PhoneAuthService.sendCodeToPhone(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    switch (result) {
      case PhoneAuthSendResult.codeSent:
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _PhoneVerificationDialog(phone: phone),
        );
        if (verified == true && mounted) {
          await _register(phoneVerified: true);
        }
      case PhoneAuthSendResult.invalidPhone:
        setState(() {
          _errorMessage = PhoneAuthService.lastErrorMessage ??
              'Please enter a valid phone number.';
        });
      case PhoneAuthSendResult.tooManyRequests:
        setState(() {
          _errorMessage = PhoneAuthService.lastErrorMessage ??
              'Too many attempts. Please try again later.';
        });
      case PhoneAuthSendResult.networkError:
      case PhoneAuthSendResult.unknownError:
        setState(() {
          _errorMessage = PhoneAuthService.lastErrorMessage ??
              'Could not send code. Please try again.';
        });
    }
  }

  Future<void> _register({required bool phoneVerified}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    final email = _emailController.text.trim();
    final phone = _toE164Au(_phoneController.text);
    final password = _passwordController.text;

    bool ok;
    try {
      ok = widget.role == 'visitor'
          ? await VisitorAuth.register(
              name: name,
              email: email,
              password: password,
              phone: phone,
            )
          : await LocalAuth.register(
              name: name,
              email: email,
              password: password,
              phone: phone,
              suburb: '',
            );
    } catch (e, st) {
      debugPrint(
        '[WelcomeSignUp] Unexpected ${widget.role} registration error: $e\n$st',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unexpected error during signup. Please try again or contact support.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) {
      final reason = widget.role == 'visitor'
          ? VisitorAuth.lastErrorMessage
          : LocalAuth.lastErrorMessage;
      debugPrint('[WelcomeSignUp] ${widget.role} registration failed: $reason');
      setState(() {
        _errorMessage = reason ?? 'Could not create account. Please try again.';
      });
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => widget.role == 'visitor'
            ? VisitorLoginScreen(
                initialEmail: _emailController.text.trim(),
              )
            : LocalLoginScreen(
                initialEmail: _emailController.text.trim(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVisitor = widget.role == 'visitor';
    return AlertDialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _cardBorder.withValues(alpha: 0.6)),
      ),
      title: Text(
        isVisitor ? 'Create Visitor Account' : 'Register Your Business',
        style: const TextStyle(
          color: _white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isVisitor
                    ? 'Sign up to explore Brisbane food and events.'
                    : 'Sign up to list your business and run promotions.',
                style: const TextStyle(color: _white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      style: const TextStyle(color: _white),
                      decoration: _dialogInputDecoration('First name'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      style: const TextStyle(color: _white),
                      decoration: _dialogInputDecoration('Last name'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: _white),
                decoration: _dialogInputDecoration('Email address'),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Please enter your email.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Please enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _white),
                decoration: _dialogInputDecoration('Phone number'),
                validator: (value) {
                  final error = PhoneValidation.validate(value);
                  if (error != null) return error;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: _white),
                decoration: _dialogInputDecoration('Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _white70,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  if (!password.contains(RegExp(r'[A-Z]'))) {
                    return 'Use at least one uppercase letter.';
                  }
                  if (!password.contains(RegExp(r'[a-z]'))) {
                    return 'Use at least one lowercase letter.';
                  }
                  if (!password.contains(RegExp(r'[0-9]'))) {
                    return 'Use at least one number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: _white),
                decoration: _dialogInputDecoration('Confirm password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _white70,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                InlineStatusMessage(
                  message: _errorMessage!,
                  type: InlineStatusType.error,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: _white70),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _startPhoneVerification,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentOrange,
            foregroundColor: _white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _white,
                  ),
                )
              : const Text(
                  'Verify Phone & Create Account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}

class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _PhoneVerificationDialog extends StatefulWidget {
  const _PhoneVerificationDialog({required this.phone});

  final String phone;

  @override
  State<_PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<_PhoneVerificationDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final ok = await PhoneAuthService.verifyCodeOnly(_codeController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = PhoneAuthService.lastErrorMessage ??
            'Invalid code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _cardBorder.withValues(alpha: 0.6)),
      ),
      title: const Text(
        'Verify Phone Number',
        style: TextStyle(
          color: _white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the 6-digit code sent to ${widget.phone}',
            style: const TextStyle(color: _white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: _white),
            decoration: _dialogInputDecoration('Verification code'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            InlineStatusMessage(
              message: _errorMessage!,
              type: InlineStatusType.error,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: _white70),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentOrange,
            foregroundColor: _white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _white,
                  ),
                )
              : const Text(
                  'Verify',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final ok = await AdminAuth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!ok) {
      setState(() => _error = AdminAuth.lastErrorMessage ?? 'Login failed.');
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).pushReplacementNamed('/admin/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Admin Access', style: TextStyle(color: _white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _white),
            decoration: _dialogInputDecoration('Admin email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: _white),
            decoration: _dialogInputDecoration('Password'),
            onSubmitted: (_) => _login(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: _white70)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentOrange,
            foregroundColor: _white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(color: _white, strokeWidth: 2),
                )
              : const Text('Sign In'),
        ),
      ],
    );
  }

  InputDecoration _dialogInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _white50.withValues(alpha: 0.7)),
      filled: true,
      fillColor: _background.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _cardBorder.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentOrange, width: 2),
      ),
    );
  }
}

// Reusable input decoration shared by the sign-up and admin dialogs.
InputDecoration _dialogInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _white50.withValues(alpha: 0.7)),
    filled: true,
    fillColor: _background.withValues(alpha: 0.5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _cardBorder.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _accentOrange, width: 2),
    ),
  );
}

// Kept for backward compatibility with any external references.
class NetflixWaveOverlayPainter extends CustomPainter {
  final double waveProgress;

  NetflixWaveOverlayPainter({required this.waveProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final glowOpacity = (math.sin(waveProgress * 2 * math.pi) + 1) / 2;
    paint.color = const Color(0xFFFF7A1A).withValues(alpha: glowOpacity * 0.6);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width - 4,
          height: size.height - 4,
        ),
        const Radius.circular(24),
      ),
      paint,
    );

    for (int i = 0; i < 2; i++) {
      final delay = i / 2;
      final progress = (waveProgress + delay) % 1.0;

      if (progress < 0.8) {
        final opacity = (1.0 - progress) * 0.5;
        paint
          ..strokeWidth = 1.5
          ..color = const Color(0xFF007BFF).withValues(alpha: opacity);

        final expandAmount = progress * 12;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: size.width + (expandAmount * 2),
              height: size.height + (expandAmount * 2),
            ),
            const Radius.circular(28),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(NetflixWaveOverlayPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress;
  }
}

class NetflixWavePainter extends CustomPainter {
  final double waveProgress;

  NetflixWavePainter({required this.waveProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final baseY = size.height / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (waveProgress * 2 * math.pi) + (i * math.pi / 3);
      final amplitude = 4.0 + i * 2;
      final frequency = 0.02 + i * 0.01;

      final path = Path();
      for (double x = 0; x < size.width; x += 2) {
        final y = baseY + math.sin(x * frequency + phase) * amplitude;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final opacity = (1.0 - i / 3) * 0.5;
      paint.color = const Color(0xFF007BFF).withValues(alpha: opacity);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(NetflixWavePainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress;
  }
}
