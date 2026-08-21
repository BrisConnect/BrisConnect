import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/features/admin/dashboard/admin_neon_theme.dart';
import 'package:brisconnect/services/admin_email_broadcast_service.dart';
import 'package:brisconnect/services/admin_message_service.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/utils/admin_utils.dart';
import 'package:brisconnect/features/admin/dashboard/widgets/admin_sidebar.dart';

class AdminEmailBroadcastScreen extends StatefulWidget {
  AdminEmailBroadcastScreen({
    super.key,
    AdminEmailBroadcastService? emailService,
    this.enforceRoleGuard = true,
    this.isEmbedded = false,
  }) : emailService = emailService ?? AdminEmailBroadcastService();

  final AdminEmailBroadcastService emailService;
  final bool enforceRoleGuard;
  final bool isEmbedded;

  @override
  State<AdminEmailBroadcastScreen> createState() =>
      _AdminEmailBroadcastScreenState();
}

class _AdminEmailBroadcastScreenState extends State<AdminEmailBroadcastScreen>
    with AdminScreenMixin<AdminEmailBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String? _audience;
  List<Map<String, String>> _locals = [];
  bool _localsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLocals();
  }

  Future<void> _loadLocals() async {
    try {
      final locals = await AdminMessageService().fetchLocalUsers();
      if (mounted) {
        setState(() {
          _locals = locals;
          _localsLoaded = true;
          _audience = 'visitors';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _localsLoaded = true;
          _audience = 'visitors';
        });
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_audience == null) return;

    await runAdminAction(
      () async {
        int queuedCount;
        if (_audience == 'visitors') {
          queuedCount = await widget.emailService.queueAdminBroadcastEmail(
            audience: 'visitors',
            subject: _subjectController.text,
            message: _messageController.text,
          );
        } else if (_audience!.startsWith('local:')) {
          final email = _audience!.substring(6);
          queuedCount = await widget.emailService.queueSingleLocalEmail(
            email: email,
            subject: _subjectController.text,
            message: _messageController.text,
          );
        } else {
          queuedCount = 0;
        }

        if (!mounted) return;

        if (queuedCount == 0) {
          showAdminSnack('No recipients found with valid email addresses.');
        } else {
          showAdminSnack('Email queued for $queuedCount recipient(s).');
        }
      },
    );
  }

  Future<void> _showAudienceDialog() async {
    await AdminUtils.showAudienceDialog(
      context,
      title: 'Select Audience',
      selectedAudience: _audience,
      locals: _locals,
      isSending: isLoading,
      onSelected: (value) => setState(() => _audience = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1024;
    final displayText = AdminUtils.audienceDisplayText(_audience, _locals);

    // Build the body content (without Scaffold wrapper for embedded case)
    final bodyContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: AdminNeonTheme.glassCard(accent: AdminNeonTheme.neonBlue, radius: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audience',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminNeonTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _localsLoaded
                    ? GestureDetector(
                        onTap: isLoading ? null : _showAudienceDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AdminNeonTheme.glassBorder),
                            borderRadius: BorderRadius.circular(8),
                            color: AdminNeonTheme.glassSurfaceAlt,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayText,
                                  style: TextStyle(
                                    color: _audience == null
                                        ? AdminNeonTheme.textMuted
                                        : AdminNeonTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: isLoading
                                    ? AdminNeonTheme.textMuted
                                    : AdminNeonTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(color: AdminNeonTheme.neonOrange),
                        ),
                      ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  enabled: !isLoading,
                  style: const TextStyle(color: AdminNeonTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: const TextStyle(color: AdminNeonTheme.textSecondary),
                    filled: true,
                    fillColor: AdminNeonTheme.glassSurfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminNeonTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminNeonTheme.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AdminNeonTheme.neonBlue),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a subject.';
                    }
                    if (value.trim().length < 4) {
                      return 'Subject should be at least 4 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 10,
                  enabled: !isLoading,
                  style: const TextStyle(color: AdminNeonTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email message',
                    labelStyle: const TextStyle(color: AdminNeonTheme.textSecondary),
                    filled: true,
                    fillColor: AdminNeonTheme.glassSurfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminNeonTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminNeonTheme.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AdminNeonTheme.neonBlue),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an email message.';
                    }
                    if (value.trim().length < 8) {
                      return 'Message should be at least 8 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use {{name}} and {{email}} to personalise each message. Emails are queued via Firestore and sent by the mail worker.',
                  style: TextStyle(
                    color: AdminNeonTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _send,
                    icon: isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.email_outlined),
                    label: Text(
                        isLoading ? 'Sending...' : 'Send Email Broadcast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminNeonTheme.neonBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // When embedded, just return the body content (no Scaffold wrapper)
    if (widget.isEmbedded) {
      final guarded = widget.enforceRoleGuard
          ? RoleGuard(
              allowedRoles: const {AppUserRole.admin},
              deniedMessage: 'Access denied. Admin privileges are required.',
              child: bodyContent,
            )
          : bodyContent;
      return guarded;
    }

    // When standalone, wrap in Scaffold with AppBar
    final content = Scaffold(
      backgroundColor: AdminNeonTheme.bgDeepNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminNeonTheme.headerBg,
        foregroundColor: AdminNeonTheme.textPrimary,
        elevation: 0,
        title: const Text(
          'Send Email Broadcast',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AdminNeonTheme.textPrimary,
          ),
        ),
      ),
      body: bodyContent,
    );

    final guarded = widget.enforceRoleGuard
        ? RoleGuard(
            allowedRoles: const {AppUserRole.admin},
            deniedMessage: 'Access denied. Admin privileges are required.',
            child: content,
          )
        : content;
    
    if (!isDesktop) return guarded;
    
    return Row(
      children: [
        AdminSidebar(
          selectedIndex: 5, // Broadcast Email
          onDestinationSelected: (index) {
            _handleNavigation(context, index);
          },
        ),
        Expanded(child: guarded),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    // index: 0=Home, 1=Users, 2=Businesses, 3=Reports, 4=Feedback, 5=Broadcast, 6=Settings
    switch (index) {
      case 0: // Home
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/dashboard',
          (route) => false,
        );
        break;
      case 1: // Users
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/users',
          (route) => false,
        );
        break;
      case 2: // Businesses
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/businesses',
          (route) => false,
        );
        break;
      case 3: // Reports
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/reports',
          (route) => false,
        );
        break;
      case 4: // Feedback
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/feedback',
          (route) => false,
        );
        break;
      case 5: // Broadcast Email - already here
        break;
      case 6: // Settings
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/admin/settings',
          (route) => false,
        );
        break;
    }
  }
}
