import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/services/email_code_auth_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/auth_validation.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/enhanced_button_styles.dart';

class VisitorLoginScreen extends StatefulWidget {
  final String? initialEmail;

  const VisitorLoginScreen({super.key, this.initialEmail});

  @override
  State<VisitorLoginScreen> createState() => _VisitorLoginScreenState();
}

class _VisitorLoginScreenState extends State<VisitorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSendingCode = false;
  bool _codeSent = false;
  String? _statusMessage;
  InlineStatusType _statusType = InlineStatusType.error;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSendingCode = true;
      _statusMessage = null;
    });

    final result = await EmailCodeAuthService.sendCode(
      email: _identifierController.text,
      userType: 'visitor',
    );

    if (!mounted) return;

    setState(() {
      _isSendingCode = false;
    });

    switch (result) {
      case SendCodeResult.sent:
        setState(() {
          _codeSent = true;
          _statusMessage = 'Code sent! Check your email.';
          _statusType = InlineStatusType.success;
        });
      case SendCodeResult.invalidEmail:
        setState(() {
          _statusMessage = EmailCodeAuthService.lastErrorMessage;
          _statusType = InlineStatusType.error;
        });
      case SendCodeResult.tooManyRequests:
        setState(() {
          _statusMessage = EmailCodeAuthService.lastErrorMessage ??
              'Please wait before requesting another code.';
          _statusType = InlineStatusType.info;
        });
      case SendCodeResult.networkError:
      case SendCodeResult.unknownError:
        setState(() {
          _statusMessage = EmailCodeAuthService.lastErrorMessage ??
              'Could not send code. Please try again.';
          _statusType = InlineStatusType.error;
        });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final success = await VisitorAuth.login(
      email: _identifierController.text,
      code: _codeController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!success) {
      setState(() {
        _statusMessage =
            VisitorAuth.lastErrorMessage ?? 'Login failed. Please try again.';
        _statusType = InlineStatusType.error;
      });
      return;
    }

    Navigator.pushReplacementNamed(context, '/visitor/portal');
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
      backgroundColor: const Color(0xFF0D1B3F),
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: BackButton(
                  color: Colors.white,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      // Logo
                      Image.asset('assets/Brisconnect New.jpg', height: 120),
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
                              const SizedBox(height: 22),

                              if (_statusMessage != null) ...[
                                InlineStatusMessage(
                                  message: _statusMessage!,
                                  type: _statusType,
                                  actionLabel: _statusType == InlineStatusType.error
                                      ? 'Retry'
                                      : null,
                                  onAction: _statusType == InlineStatusType.error
                                      ? (_isSubmitting ? null : _login)
                                      : null,
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Email
                              TextFormField(
                                controller: _identifierController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppPalette.charcoal),
                                decoration: _fieldDecoration(
                                  hintText: 'Email',
                                  prefixIcon: Icons.mail_outline,
                                ),
                                validator: AuthValidation.email,
                              ),
                              const SizedBox(height: 14),

                              // Code
                              TextFormField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(color: AppPalette.charcoal),
                                decoration: _fieldDecoration(
                                  hintText: 'Enter 6-digit code',
                                  prefixIcon: Icons.vpn_key_outlined,
                                ),
                                validator: (v) =>
                                    AuthValidation.requiredField(v, 'Code'),
                              ),
                              const SizedBox(height: 12),

                              // Send code / Log In buttons
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSendingCode ? null : _sendCode,
                                  style: EnhancedButtonStyles.fullWidthPrimaryButton(),
                                  child: _isSendingCode
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _codeSent ? 'Resend Code' : 'Send Code',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.surfaceAlt,
                                    foregroundColor: AppPalette.ochre,
                                    disabledBackgroundColor:
                                        AppPalette.surfaceAlt.withValues(alpha: 0.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: const BorderSide(color: AppPalette.ochre),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppPalette.ochre,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Verify & Log In',
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
                                              const VisitorSignUpScreen(),
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
