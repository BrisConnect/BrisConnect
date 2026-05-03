import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/local_signup_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/auth_validation.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';

class LocalLoginScreen extends StatefulWidget {
  final String? initialEmail;

  const LocalLoginScreen({super.key, this.initialEmail});

  @override
  State<LocalLoginScreen> createState() => _LocalLoginScreenState();
}

class _LocalLoginScreenState extends State<LocalLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await LocalAuth.login(
      email: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!success) {
      setState(() {
        _errorMessage = LocalAuth.lastErrorMessage ?? 'Login failed. Please try again.';
      });
      return;
    }

    // Check if the logged-in user is rejected
    final currentUser = LocalAuth.currentLocal;
    if (currentUser != null && currentUser.approvalStatus == AccountApprovalStatus.rejected) {
      await LocalAuth.logout();
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Your account has been rejected. Please contact support.';
      });
      return;
    }

    Navigator.pushReplacementNamed(context, '/local/portal');
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppPalette.mutedText.withValues(alpha: 0.6)),
      filled: true,
      fillColor: AppPalette.background.withValues(alpha: 0.5),
      prefixIcon: Icon(prefixIcon, color: AppPalette.mutedText, size: 20),
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AboriginalDotArtBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      // Logo
                      Image.asset('assets/logo.png', height: 120),
                      const SizedBox(height: 20),

                      // Card
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        decoration: BoxDecoration(
                          color: AppPalette.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: AppPalette.cardShadow,
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Local badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: AppPalette.surfaceAlt,
                                  border: Border.all(color: AppPalette.border),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.place,
                                        color: AppPalette.ochre, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Local Account',
                                      style: TextStyle(
                                        color: AppPalette.deepBlue,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (_errorMessage != null) ...[
                                InlineStatusMessage(
                                  message: _errorMessage!,
                                  type: InlineStatusType.error,
                                  actionLabel: 'Retry',
                                  onAction: _isSubmitting ? null : _login,
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Email or Username
                              TextFormField(
                                controller: _identifierController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppPalette.charcoal),
                                decoration: _fieldDecoration(
                                  hintText: 'Email or Username',
                                  prefixIcon: Icons.mail_outline,
                                ),
                                validator: AuthValidation.emailOrUsername,
                              ),
                              const SizedBox(height: 14),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: AppPalette.charcoal),
                                decoration: _fieldDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppPalette.mutedText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    AuthValidation.requiredField(v, 'Password'),
                              ),
                              const SizedBox(height: 24),

                              // Log In button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.ochre,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Log In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // No account yet
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No account yet?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppPalette.mutedText,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const LocalSignUpScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Register',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.ochre,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      ),
    );
  }
}
