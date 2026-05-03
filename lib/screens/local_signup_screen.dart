import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/local_login_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/auth_validation.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';

class LocalSignUpScreen extends StatefulWidget {
  const LocalSignUpScreen({super.key});

  @override
  State<LocalSignUpScreen> createState() => _LocalSignUpScreenState();
}

class _LocalSignUpScreenState extends State<LocalSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _suburbController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  String _toE164Au(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('61')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+61$digits';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _suburbController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final registered = await LocalAuth.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _toE164Au(_phoneController.text),
      suburb: _suburbController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!registered) {
      final reason = LocalAuth.lastErrorMessage ?? 'Could not create Local account.';
      debugPrint('[LocalSignUp] Registration failed: $reason');
      setState(() {
        _errorMessage = reason;
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LocalLoginScreen(initialEmail: _emailController.text),
      ),
    );
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
                      GestureDetector(
                        onTap: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginSelectionScreen()),
                          (_) => false,
                        ),
                        child: Image.asset('assets/logo.png', height: 120),
                      ),
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
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: [
                              const Text(
                                'Create Your Account',
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
                                  onAction: _isSubmitting ? null : _register,
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: _fieldDecoration(
                                  hintText: 'Full Name',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (v) =>
                                    AuthValidation.requiredField(v, 'Name'),
                              ),
                              const SizedBox(height: 14),

                              // Suburb
                              TextFormField(
                                controller: _suburbController,
                                textCapitalization: TextCapitalization.words,
                                decoration: _fieldDecoration(
                                  hintText: 'Suburb',
                                  prefixIcon: Icons.location_city_outlined,
                                ),
                                validator: (v) =>
                                    AuthValidation.requiredField(v, 'Suburb'),
                              ),
                              const SizedBox(height: 14),

                              // Phone Number
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: _fieldDecoration(
                                  hintText: 'Phone Number (e.g. 04XX XXX XXX)',
                                  prefixIcon: Icons.phone_outlined,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  final digits = v.replaceAll(RegExp(r'\D'), '');
                                  if (digits.length < 10) {
                                    return 'Enter a valid Australian phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _fieldDecoration(
                                  hintText: 'Email',
                                  prefixIcon: Icons.mail_outline,
                                ),
                                validator: AuthValidation.email,
                              ),
                              const SizedBox(height: 14),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
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
                                validator: AuthValidation.password,
                              ),
                              const SizedBox(height: 14),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                decoration: _fieldDecoration(
                                  hintText: 'Confirm Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppPalette.mutedText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Confirm your password';
                                  }
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Terms
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedText,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(text: 'By signing up, you agree to our '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.charcoal,
                                      ),
                                    ),
                                    TextSpan(text: '\nand '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.charcoal,
                                      ),
                                    ),
                                    TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Sign Up button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _register,
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
                                              'Sign Up',
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

                              // Already have account
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account?',
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
                                              const LocalLoginScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Log In',
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
