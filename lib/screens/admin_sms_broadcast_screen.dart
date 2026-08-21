import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/services/admin_message_service.dart';
import 'package:brisconnect/services/sms_notification_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/utils/admin_utils.dart';

class AdminSmsBroadcastScreen extends StatefulWidget {
  AdminSmsBroadcastScreen({
    super.key,
    SmsNotificationService? smsService,
    this.enforceRoleGuard = true,
  }) : smsService = smsService ?? SmsNotificationService();

  final SmsNotificationService smsService;
  final bool enforceRoleGuard;

  @override
  State<AdminSmsBroadcastScreen> createState() =>
      _AdminSmsBroadcastScreenState();
}

class _AdminSmsBroadcastScreenState extends State<AdminSmsBroadcastScreen>
    with AdminScreenMixin<AdminSmsBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
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
          queuedCount = await widget.smsService.queueAdminBroadcastSms(
            audience: 'visitors',
            message: _messageController.text,
          );
        } else if (_audience!.startsWith('local:')) {
          final email = _audience!.substring(6);
          queuedCount = await widget.smsService.queueSingleLocalSms(
            email: email,
            message: _messageController.text,
          );
        } else {
          queuedCount = 0;
        }

        if (!mounted) return;

        if (queuedCount == 0) {
          showAdminSnack('No recipients found with valid phone numbers.');
        } else {
          showAdminSnack('SMS sent to $queuedCount recipient(s).');
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
    final displayText = AdminUtils.audienceDisplayText(_audience, _locals);

    final content = Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFEBF4FF),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: const Text(
          'Send SMS Broadcast',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
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
                          onTap: isLoading ? null : _showAudienceDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
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
                                      color: _audience == null
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color:
                                      isLoading ? Colors.grey : Colors.black54,
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
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 8,
                    enabled: !isLoading,
                    style: const TextStyle(color: Colors.black),
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
                      onPressed: isLoading ? null : _send,
                      icon: isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sms_outlined),
                      label:
                          Text(isLoading ? 'Sending...' : 'Send SMS Broadcast'),
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
