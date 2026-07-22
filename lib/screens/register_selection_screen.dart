import 'package:flutter/material.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/local_signup_screen.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/screens/welcome_screen_new.dart';
import 'package:brisconnect/theme/app_palette.dart';

class RegisterSelectionScreen extends StatefulWidget {
  const RegisterSelectionScreen({super.key});

  @override
  State<RegisterSelectionScreen> createState() => _RegisterSelectionScreenState();
}

class _RegisterSelectionScreenState extends State<RegisterSelectionScreen> {
  String? _selectedRole;

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

  void _onRoleChanged(String? role) {
    setState(() => _selectedRole = role);
  }

  void _continueToRegistration() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose account type')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _selectedRole == 'Visitor'
            ? const VisitorSignUpScreen()
            : const LocalSignUpScreen(),
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
                      onPressed: _handleBackPressed,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      style: IconButton.styleFrom(backgroundColor: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Image.asset('assets/Brisconnect New.jpg', height: 120),
                  const SizedBox(height: 20),

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
                        const Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select account type to register',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppPalette.mutedText),
                        ),
                        const SizedBox(height: 22),

                        Theme(
                          data: Theme.of(context).copyWith(canvasColor: AppPalette.surfaceAlt),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            hint: const Text(
                              'Choose account type',
                              style: TextStyle(color: AppPalette.mutedText),
                            ),
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
                              prefixIcon: const Icon(
                                Icons.app_registration_rounded,
                                color: AppPalette.ochre,
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppPalette.ochre.withValues(alpha: 0.4),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppPalette.ochre,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Visitor', child: Text('Visitor')),
                              DropdownMenuItem(value: 'Local', child: Text('Local')),
                            ],
                            onChanged: _onRoleChanged,
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _continueToRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.ochre,
                              foregroundColor: Colors.white,
                              shadowColor: AppPalette.ochre.withValues(alpha: 0.5),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account?',
                              style: TextStyle(fontSize: 13, color: AppPalette.mutedText),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginSelectionScreen(),
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
