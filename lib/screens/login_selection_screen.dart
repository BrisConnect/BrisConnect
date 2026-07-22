import 'package:flutter/material.dart';
import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/screens/local_signup_screen.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/auth_validation.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';

class LoginSelectionScreen extends StatefulWidget {
  const LoginSelectionScreen({super.key});

  @override
  State<LoginSelectionScreen> createState() => _LoginSelectionScreenState();
}

class _LoginSelectionScreenState extends State<LoginSelectionScreen> {
  int _adminTapCount = 0;
  bool _showAdminOption = false;
  String? _selectedRole;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  void _handleBackPressed() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const AnimatedWelcomeScreen()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onTitleTap() {
    _adminTapCount++;
    if (_adminTapCount >= 5 && !_showAdminOption) {
      setState(() => _showAdminOption = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin login unlocked'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onRoleChanged(String? role) {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      _obscurePassword = true;
    });
    _emailController.clear();
    _passwordController.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    switch (_selectedRole) {
      case 'Visitor':
        final ok = await VisitorAuth.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (!ok) {
          setState(() => _errorMessage = VisitorAuth.lastErrorMessage ??
              'Login failed. Please try again.');
          return;
        }
        Navigator.pushReplacementNamed(context, '/visitor/portal');
        break;
      case 'Local':
        final ok = await LocalAuth.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (!ok) {
          setState(() => _errorMessage =
              LocalAuth.lastErrorMessage ?? 'Login failed. Please try again.');
          return;
        }
        final currentUser = LocalAuth.currentLocal;
        if (currentUser != null &&
            currentUser.approvalStatus == AccountApprovalStatus.rejected) {
          await LocalAuth.logout();
          if (!mounted) return;
          setState(() => _errorMessage =
              'Your account has been rejected. Please contact support.');
          return;
        }
        Navigator.pushReplacementNamed(context, '/local/portal');
        break;
      case 'Admin':
        final ok = await AdminAuth.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (!ok) {
          setState(() => _errorMessage =
              AdminAuth.lastErrorMessage ?? 'Invalid admin credentials.');
          return;
        }
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
        break;
    }
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

  String get _cardTitle {
    switch (_selectedRole) {
      case 'Visitor':
        return 'Visitor Login';
      case 'Local':
        return 'Local Login';
      case 'Admin':
        return 'Admin Login';
      default:
        return 'Log In';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = <String>['Visitor', 'Local', if (_showAdminOption) 'Admin'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3F),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      // Back button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _handleBackPressed,
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white24),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Logo
                      Image.asset('assets/Brisconnect New.jpg', height: 120),
                      const SizedBox(height: 20),

                      // Card
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title (tap 5× to unlock Admin)
                            GestureDetector(
                              onTap: _onTitleTap,
                              child: Text(
                                _cardTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Select your account type',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: AppPalette.mutedText),
                            ),
                            const SizedBox(height: 22),

                            // Role dropdown
                            Theme(
                              data: Theme.of(context)
                                  .copyWith(canvasColor: AppPalette.surfaceAlt),
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                hint: const Text('Choose account type',
                                    style:
                                        TextStyle(color: AppPalette.mutedText)),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                dropdownColor: AppPalette.surfaceAlt,
                                iconEnabledColor: AppPalette.ochre,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppPalette.surfaceAlt,
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: AppPalette.ochre, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: AppPalette.ochre
                                            .withValues(alpha: 0.4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: AppPalette.ochre, width: 1.5),
                                  ),
                                ),
                                isExpanded: true,
                                items: roles
                                    .map((r) => DropdownMenuItem(
                                        value: r, child: Text(r)))
                                    .toList(),
                                onChanged: _onRoleChanged,
                              ),
                            ),

                            // Animated login fields
                            AnimatedSize(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                              child: _selectedRole == null
                                  ? const SizedBox.shrink()
                                  : Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const SizedBox(height: 20),

                                          if (_errorMessage != null) ...[
                                            InlineStatusMessage(
                                              message: _errorMessage!,
                                              type: InlineStatusType.error,
                                              actionLabel: 'Retry',
                                              onAction: _isSubmitting
                                                  ? null
                                                  : _submit,
                                            ),
                                            const SizedBox(height: 10),
                                          ],

                                          // Email / Username
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            style: const TextStyle(
                                                color: AppPalette.charcoal),
                                            decoration: _fieldDecoration(
                                              hintText: _selectedRole == 'Admin'
                                                  ? 'Admin Email'
                                                  : 'Email or Username',
                                              prefixIcon: Icons.mail_outline,
                                            ),
                                            validator: _selectedRole == 'Admin'
                                                ? AuthValidation.email
                                                : AuthValidation
                                                    .emailOrUsername,
                                          ),
                                          const SizedBox(height: 14),

                                          // Password
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            style: const TextStyle(
                                                color: AppPalette.charcoal),
                                            decoration: _fieldDecoration(
                                              hintText: 'Password',
                                              prefixIcon: Icons.lock_outline,
                                              suffixIcon: IconButton(
                                                onPressed: () => setState(() =>
                                                    _obscurePassword =
                                                        !_obscurePassword),
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                          .visibility_outlined
                                                      : Icons
                                                          .visibility_off_outlined,
                                                  color: AppPalette.mutedText,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                            validator: (v) =>
                                                AuthValidation.requiredField(
                                                    v, 'Password'),
                                          ),
                                          const SizedBox(height: 22),

                                          // Log In button
                                          SizedBox(
                                            height: 52,
                                            child: ElevatedButton(
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : _submit,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppPalette.ochre,
                                                foregroundColor: Colors.white,
                                                shadowColor: AppPalette.ochre
                                                    .withValues(alpha: 0.5),
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: _isSubmitting
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white),
                                                    )
                                                  : const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text('Log In',
                                                            style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                        SizedBox(width: 8),
                                                        Icon(
                                                            Icons.arrow_forward,
                                                            size: 20),
                                                      ],
                                                    ),
                                            ),
                                          ),

                                          // Register link (Visitor & Local only)
                                          if (_selectedRole != 'Admin') ...[
                                            const SizedBox(height: 14),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'No account yet?',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color:
                                                          AppPalette.mutedText),
                                                ),
                                                const SizedBox(width: 4),
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => _selectedRole ==
                                                                'Visitor'
                                                            ? const VisitorSignUpScreen()
                                                            : const LocalSignUpScreen(),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Register',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppPalette.ochre,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                            ),
                          ],
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
