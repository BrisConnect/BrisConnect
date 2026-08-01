import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/services/phone_auth_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/auth_validation.dart';
import 'package:brisconnect/utils/phone_validation.dart';
import 'package:brisconnect/utils/profile_image_utils.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/phone_verification_dialog.dart';

class VisitorSignUpScreen extends StatefulWidget {
  const VisitorSignUpScreen({super.key});

  @override
  State<VisitorSignUpScreen> createState() => _VisitorSignUpScreenState();
}

class _VisitorSignUpScreenState extends State<VisitorSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Uint8List? _profileImageBytes;
  String? _profileImageFileName;

  String _toE164Au(String value) {
    return PhoneValidation.toE164Au(value) ?? '';
  }

  Future<void> _startPhoneVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final phone = _toE164Au(_phoneController.text);
    final result = await PhoneAuthService.sendCodeToPhone(phone);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result) {
      case PhoneAuthSendResult.codeSent:
        final verified = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => PhoneVerificationDialog(phone: phone),
        );
        if (verified == true && mounted) {
          await _register();
        }
      case PhoneAuthSendResult.invalidPhone:
        setState(() => _errorMessage =
            PhoneAuthService.lastErrorMessage ?? 'Please enter a valid phone number.');
      case PhoneAuthSendResult.tooManyRequests:
        setState(() => _errorMessage =
            PhoneAuthService.lastErrorMessage ?? 'Too many attempts. Please try again later.');
      case PhoneAuthSendResult.networkError:
      case PhoneAuthSendResult.unknownError:
        setState(() => _errorMessage =
            PhoneAuthService.lastErrorMessage ?? 'Could not send code. Please try again.');
    }
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    if (_isSubmitting) return;

    final source = await _pickImageSource();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 720,
      maxHeight: 720,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!ProfileImageUtils.isSupportedImage(bytes)) {
      setState(() => _profileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only JPG and PNG images are supported.')),
      );
      return;
    }

    if (bytes.length > ProfileImageUtils.maxImageBytes) {
      setState(() => _profileImageBytes = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image is too large.')),
      );
      return;
    }

    setState(() {
      _profileImageBytes = bytes;
      _profileImageFileName = picked.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    String? profileImageUrl;
    String? profileImageStoragePath;

    if (_profileImageBytes != null && _profileImageFileName != null) {
      try {
        final uploaded = await FirebaseMediaService().uploadProfileImage(
          role: 'visitor',
          email: _emailController.text.trim().toLowerCase(),
          bytes: _profileImageBytes!,
          fileName: _profileImageFileName!,
        );
        profileImageUrl = uploaded.downloadUrl;
        profileImageStoragePath = uploaded.storagePath;
      } on FormatException catch (error) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = error.message;
        });
        return;
      } catch (error) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Could not upload profile picture. Please try again.';
        });
        return;
      }
    }

    final registered = await VisitorAuth.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _toE164Au(_phoneController.text),
      profileImageUrl: profileImageUrl,
      profileImageStoragePath: profileImageStoragePath,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!registered) {
      setState(() {
        _errorMessage =
            VisitorAuth.lastErrorMessage ?? 'Could not create account. Please try again.';
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisitorLoginScreen(initialEmail: _emailController.text),
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
      backgroundColor: const Color(0xFF0D1B3F),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Image.asset('assets/Brisconnect New.jpg', height: 120),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    decoration: BoxDecoration(
                      color: AppPalette.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppPalette.ochre.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.ochre.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Visitor Registration',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create your visitor account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppPalette.mutedText,
                                ),
                              ),
                              const SizedBox(height: 22),

                              if (_errorMessage != null) ...[
                                InlineStatusMessage(
                                  message: _errorMessage!,
                                  type: InlineStatusType.error,
                                  actionLabel: 'Retry',
                                  onAction: _isSubmitting ? null : _startPhoneVerification,
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Profile picture
                              Center(
                                child: GestureDetector(
                                  onTap: _isSubmitting ? null : _pickProfileImage,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 54,
                                        backgroundColor: AppPalette.deepBlue,
                                        backgroundImage: _profileImageBytes != null
                                            ? MemoryImage(_profileImageBytes!)
                                            : null,
                                        child: _profileImageBytes == null
                                            ? const Icon(
                                                Icons.person_rounded,
                                                color: Colors.white,
                                                size: 48,
                                              )
                                            : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppPalette.ochre,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Tap to add profile picture',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                key: const Key('visitor-signup-name-field'),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _fieldDecoration(
                                  hintText: 'Name',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (v) =>
                                    AuthValidation.requiredField(v, 'Name'),
                              ),
                              const SizedBox(height: 14),

                              // Phone Number
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                key: const Key('visitor-signup-phone-field'),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _fieldDecoration(
                                  hintText: 'Phone Number (e.g. 0412 345 678)',
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
                              const SizedBox(height: 6),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Used for SMS. Must be a valid AU number (+61 / E.164).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedText,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                key: const Key('visitor-signup-email-field'),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                key: const Key('visitor-signup-password-field'),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _fieldDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
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
                                key: const Key('visitor-signup-confirm-password-field'),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
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
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedText,
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: 'By signing up, you agree to our '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => Navigator.of(context).pushNamed('/terms-of-service'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.charcoal,
                                      ),
                                    ),
                                    const TextSpan(text: '\nand '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => Navigator.of(context).pushNamed('/privacy-policy'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.charcoal,
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Sign Up button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _startPhoneVerification,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppPalette.ochre,
                                    foregroundColor: Colors.white,
                                    shadowColor:
                                        AppPalette.ochre.withValues(alpha: 0.5),
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
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
                                              'Create Account',
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
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  const Text(
                                    'Already have an account?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppPalette.mutedText,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const VisitorLoginScreen(),
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
    );
  }
}
