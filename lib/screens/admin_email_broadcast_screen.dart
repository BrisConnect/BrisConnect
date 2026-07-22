import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/services/admin_email_broadcast_service.dart';
import 'package:brisconnect/services/admin_message_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';

class AdminEmailBroadcastScreen extends StatefulWidget {
  AdminEmailBroadcastScreen({
    super.key,
    AdminEmailBroadcastService? emailService,
    this.enforceRoleGuard = true,
  }) : emailService = emailService ?? AdminEmailBroadcastService();

  final AdminEmailBroadcastService emailService;
  final bool enforceRoleGuard;

  @override
  State<AdminEmailBroadcastScreen> createState() =>
      _AdminEmailBroadcastScreenState();
}

class _AdminEmailBroadcastScreenState
    extends State<AdminEmailBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String? _audience;
  List<Map<String, String>> _locals = [];
  bool _localsLoaded = false;
  bool _isSending = false;

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

    setState(() => _isSending = true);
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recipients found with valid email addresses.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email queued for $queuedCount recipient(s).'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send email: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showAudienceDialog() async {
    final audienceOptions = <Map<String, String>>[
      {'value': 'visitors', 'label': 'All Visitors'},
      ..._locals.map((local) => {
            'value': 'local:${local['email'] ?? ''}',
            'label': '${local['name'] ?? ''} (${local['email'] ?? ''})',
          }),
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Audience'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...audienceOptions.map((option) {
                final value = option['value']!;
                final label = option['label']!;
                final isSelected = _audience == value;
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: _isSending ? null : (_) {
                      setState(() => _audience = value);
                      Navigator.of(ctx).pop();
                    },
                  ),
                  title: Text(label),
                  onTap: _isSending ? null : () {
                    setState(() => _audience = value);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayText = _audience == null
        ? 'Select Audience'
        : _audience == 'visitors'
            ? 'All Visitors'
            : _locals.firstWhere(
                (local) => _audience == 'local:${local['email']}',
                orElse: () => {'name': '', 'email': ''},
              )['name'] ?? 'All Visitors';

    final content = Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Send Email Broadcast'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: AppPalette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppPalette.border),
          ),
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
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _localsLoaded
                      ? GestureDetector(
                          onTap: _isSending ? null : _showAudienceDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayText,
                                    style: TextStyle(
                                      color: _audience == null ? Colors.grey : Colors.black,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: _isSending ? Colors.grey : Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_isSending,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
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
                    enabled: !_isSending,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      labelText: 'Email message',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
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
                    'Emails are queued via Firestore and sent through the mail extension.',
                    style: TextStyle(
                      color: AppPalette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _send,
                      icon: _isSending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.email_outlined),
                      label: Text(
                          _isSending ? 'Sending...' : 'Send Email Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.deepBlue,
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
      ),
    );

    if (!widget.enforceRoleGuard) return content;

    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: content,
    );
  }
}
