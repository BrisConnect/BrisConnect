import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
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
  String? _selectedSuburb;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  void _handleBackPressed() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LocalLoginScreen()),
    );
  }

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
      suburb: _selectedSuburb ?? '',
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
                                'Local Registration',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create your local account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppPalette.mutedText,
                                ),
                              ),
                              const SizedBox(height: 16),

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
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _fieldDecoration(
                                  hintText: 'Full Name',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (v) =>
                                    AuthValidation.requiredField(v, 'Name'),
                              ),
                              const SizedBox(height: 14),

                              // Suburb dropdown
                              DropdownButtonFormField<String>(
                                initialValue: _selectedSuburb,
                                decoration: _fieldDecoration(
                                  hintText: 'Select Suburb',
                                  prefixIcon: Icons.location_city_outlined,
                                ),
                                style: const TextStyle(
                                  color: AppPalette.charcoal,
                                  fontWeight: FontWeight.w500,
                                ),
                                dropdownColor: AppPalette.surfaceAlt,
                                isExpanded: true,
                                items: const [
                                  'Acacia Ridge', 'Albion', 'Alderley', 'Algester',
                                  'Annerley', 'Anstead', 'Archerfield', 'Ascot',
                                  'Ashgrove', 'Aspley', 'Auchenflower',
                                  'Balmoral', 'Banyo', 'Bardon', 'Bellbowrie',
                                  'Belmont', 'Boondall', 'Bowen Hills', 'Bracken Ridge',
                                  'Bridgeman Downs', 'Brighton', 'Brisbane City',
                                  'Brookfield', 'Bulimba', 'Bundamba',
                                  'Calamvale', 'Camp Hill', 'Cannon Hill',
                                  'Capalaba', 'Carindale', 'Carseldine',
                                  'Chandler', 'Chapel Hill', 'Chermside',
                                  'Chermside West', 'Clayfield', 'Cleveland',
                                  'Coorparoo', 'Corinda',
                                  'Darra', 'Deagon', 'Doolandella', 'Drewvale',
                                  'Durack',
                                  'Eagle Farm', 'East Brisbane', 'Eight Mile Plains',
                                  'Ekibin', 'Ellen Grove', 'Enoggera', 'Everton Hills',
                                  'Everton Park',
                                  'Fairfield', 'Fig Tree Pocket', 'Fitzgibbon',
                                  'Forest Lake', 'Fortitude Valley',
                                  'Gaythorne', 'Geebung', 'Gordon Park',
                                  'Graceville', 'Greenslopes', 'Gumdale',
                                  'Hamilton', 'Hawthorne', 'Hemmant',
                                  'Hendra', 'Holland Park', 'Holland Park West',
                                  'Inala', 'Indooroopilly', 'Ipswich',
                                  'Jamboree Heights', 'Jindalee',
                                  'Karana Downs', 'Kedron', 'Kelvin Grove',
                                  'Kenmore', 'Kenmore Hills', 'Keperra',
                                  'Kuraby',
                                  'Lota',
                                  'Macgregor', 'Mackenzie', 'Manly',
                                  'Manly West', 'Mansfield', 'McDowall',
                                  'Middle Park', 'Milton', 'Mitchelton',
                                  'Moggill', 'Moorooka', 'Morningside',
                                  'Mount Coot-tha', 'Mount Gravatt',
                                  'Mount Gravatt East', 'Mount Ommaney',
                                  'Murarrie',
                                  'Nathan', 'New Farm', 'Newmarket',
                                  'Newstead', 'Norman Park', 'Northgate',
                                  'Nudgee', 'Nudgee Beach', 'Nundah',
                                  'Oxley',
                                  'Paddington', 'Pallara', 'Parkinson',
                                  'Petrie Terrace', 'Pinkenba',
                                  'Rainbow', 'Raceview', 'Ransome',
                                  'Red Hill', 'Richlands', 'Robertson',
                                  'Rocklea', 'Runcorn',
                                  'Salisbury', 'Seventeen Mile Rocks',
                                  'Sherwood', 'Shorncliffe', 'Sinnamon Park',
                                  'South Brisbane', 'Spring Hill',
                                  'Stafford', 'Stafford Heights',
                                  'Stretton', 'Sumner', 'Sunnybank',
                                  'Sunnybank Hills',
                                  'Taigum', 'Tarragindi', 'Tennyson',
                                  'The Gap', 'Tingalpa', 'Toowong',
                                  'Torwood', 'Turrella',
                                  'Upper Kedron', 'Upper Mount Gravatt',
                                  'Virginia',
                                  'Wakerley', 'Wavell Heights', 'West End',
                                  'Westlake', 'Willawong', 'Wilston',
                                  'Windsor', 'Wishart', 'Woolloongabba',
                                  'Wooloowin', 'Wynn Vale',
                                  'Wynnum', 'Wynnum West',
                                  'Yeerongpilly', 'Yeronga',
                                  'Zillmere',
                                ].map((suburb) => DropdownMenuItem(
                                  value: suburb,
                                  child: Text(
                                    suburb,
                                    style: const TextStyle(
                                      color: AppPalette.charcoal,
                                    ),
                                  ),
                                )).toList(),
                                onChanged: (value) =>
                                    setState(() => _selectedSuburb = value),
                                validator: (v) => v == null
                                    ? 'Please select your suburb'
                                    : null,
                              ),
                              const SizedBox(height: 14),

                              // Phone Number
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
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
    );
  }
}

