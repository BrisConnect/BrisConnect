import 'package:flutter/material.dart';
import 'package:brisconnect/services/email_verification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String redirectRoute;
  final EmailVerificationService? verificationService;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.redirectRoute = '/visitor/portal',
    this.verificationService,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late final EmailVerificationService _verificationService;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isVerified = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _verificationService =
        widget.verificationService ?? EmailVerificationService();
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    final verified = await _verificationService.isEmailVerified();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isVerified = verified;
    });

    if (verified) {
      setState(() {
        _statusMessage = 'Email verified successfully!';
        _isSuccess = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, widget.redirectRoute);
    } else {
      setState(() {
        _statusMessage = 'Email not yet verified. Please check your inbox.';
        _isSuccess = false;
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });

    final sent = await _verificationService.sendVerificationEmail();

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (sent) {
        _statusMessage = 'Verification email sent to ${widget.email}';
        _isSuccess = true;
      } else {
        _statusMessage = 'Could not send verification email. Try again later.';
        _isSuccess = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const LogoAppBarTitle('Verify Email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppPalette.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppPalette.cardShadow,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isVerified
                        ? Icons.mark_email_read_rounded
                        : Icons.email_outlined,
                    size: 64,
                    color:
                        _isVerified ? AppPalette.deepBlue : AppPalette.ochre,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isVerified
                        ? 'Email Verified!'
                        : 'Verify Your Email',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isVerified
                        ? 'Your account is confirmed.'
                        : 'A verification email has been sent to:',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppPalette.mutedText,
                    ),
                  ),
                  if (!_isVerified) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please check your inbox and click the verification link, '
                      'then tap the button below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppPalette.mutedText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_statusMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _isSuccess
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isSuccess
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isSuccess
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (!_isVerified) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _checkVerification,
                        icon: _isChecking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text("I've Verified My Email"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.deepBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isResending ? null : _resendVerification,
                        icon: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Resend Verification Email'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.ochre,
                          side: const BorderSide(color: AppPalette.ochre),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
