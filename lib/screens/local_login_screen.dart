import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/local_signup_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/utils/auth_validation.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const LogoAppBarTitle('Local Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
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
              child: Form(
                key: _formKey,
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                InlineStatusMessage(
                  message: _errorMessage!,
                  type: InlineStatusType.error,
                  actionLabel: 'Retry',
                  onAction: _isSubmitting ? null : _login,
                ),
              TextFormField(
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email or Username',
                  hintText: 'Enter your email or username',
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email, color: AppPalette.ochre),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppPalette.deepBlue),
                  ),
                ),
                validator: AuthValidation.emailOrUsername,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock, color: AppPalette.deepBlue),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppPalette.deepBlue),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                  ),
                ),
                validator: (v) => AuthValidation.requiredField(v, 'Password'),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _login,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.ochre,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LocalSignUpScreen()),
                  );
                },
                child: const Text(
                  'No Local account yet? Register',
                  style: TextStyle(color: AppPalette.deepBlue),
                ),
              ),
            ],
          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
