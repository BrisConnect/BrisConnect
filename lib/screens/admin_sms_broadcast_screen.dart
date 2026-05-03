import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';

class AdminSmsBroadcastScreen extends StatefulWidget {
  AdminSmsBroadcastScreen({
    super.key,
    SmsNotificationService? smsService,
    this.enforceRoleGuard = true,
  }) : smsService = smsService ?? SmsNotificationService();

  final SmsNotificationService smsService;
  final bool enforceRoleGuard;

  @override
  State<AdminSmsBroadcastScreen> createState() => _AdminSmsBroadcastScreenState();
}

class _AdminSmsBroadcastScreenState extends State<AdminSmsBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  String _audience = 'both';
  bool _approvedLocalsOnly = true;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final queuedCount = await widget.smsService.queueAdminBroadcastSms(
        audience: _audience,
        message: _messageController.text,
        approvedLocalsOnly: _approvedLocalsOnly,
      );

      if (!mounted) {
        return;
      }

      if (queuedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recipients found with valid phone numbers.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS sent to $queuedCount recipient(s).'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SMS: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Send SMS Broadcast'),
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
                    DropdownButtonFormField<String>(
                      initialValue: _audience,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'both', child: Text('Locals and Visitors')),
                        DropdownMenuItem(value: 'locals', child: Text('Locals only')),
                        DropdownMenuItem(value: 'visitors', child: Text('Visitors only')),
                      ],
                      onChanged: _isSending
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _audience = value);
                            },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _approvedLocalsOnly,
                      title: const Text('Approved locals only'),
                      subtitle: const Text(
                        'Applies when locals are included in audience.',
                      ),
                      onChanged: _isSending
                          ? null
                          : (value) {
                              setState(() => _approvedLocalsOnly = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageController,
                      minLines: 4,
                      maxLines: 8,
                      enabled: !_isSending,
                      decoration: const InputDecoration(
                        labelText: 'SMS message',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an SMS message.';
                        }
                        if (value.trim().length < 8) {
                          return 'Message should be at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Messages are sent via Twilio to the selected audience.',
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
                            : const Icon(Icons.sms_outlined),
                        label: Text(_isSending ? 'Sending...' : 'Send SMS Broadcast'),
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

    if (!widget.enforceRoleGuard) {
      return content;
    }
    return RoleGuard(
      allowedRoles: const {AppUserRole.admin},
      deniedMessage: 'Access denied. Admin privileges are required.',
      child: content,
    );
  }
}
