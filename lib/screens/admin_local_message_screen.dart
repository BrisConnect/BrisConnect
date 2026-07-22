import 'package:brisconnect/auth/admin_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/services/admin_message_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';
import 'package:flutter/material.dart';

class AdminLocalMessageScreen extends StatefulWidget {
  AdminLocalMessageScreen({
    super.key,
    AdminMessageService? messageService,
    this.enforceRoleGuard = true,
    this.preselectedEmail,
    this.preselectedEventId,
    this.preselectedEventTitle,
    this.preselectedType,
  }) : messageService = messageService ?? AdminMessageService();

  final AdminMessageService messageService;
  final bool enforceRoleGuard;
  final String? preselectedEmail;
  final String? preselectedEventId;
  final String? preselectedEventTitle;
  final AdminMessageType? preselectedType;

  @override
  State<AdminLocalMessageScreen> createState() =>
      _AdminLocalMessageScreenState();
}

class _AdminLocalMessageScreenState extends State<AdminLocalMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  List<Map<String, String>> _locals = [];
  String? _selectedEmail;
  AdminMessageType _selectedType = AdminMessageType.general;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedEmail = widget.preselectedEmail;
    _selectedType = widget.preselectedType ?? AdminMessageType.general;

    if (widget.preselectedEventTitle != null) {
      _subjectController.text =
          '${_selectedType.label}: ${widget.preselectedEventTitle}';
    }

    _loadLocals();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadLocals() async {
    try {
      final locals = await widget.messageService.fetchLocalUsers();
      if (mounted) {
        setState(() {
          _locals = locals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a local user.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await widget.messageService.sendMessage(
        toEmail: _selectedEmail!,
        subject: _subjectController.text,
        message: _messageController.text,
        type: _selectedType,
        sentBy: AdminAuth.currentAdminEmail ?? 'admin',
        eventId: widget.preselectedEventId,
        eventTitle: widget.preselectedEventTitle,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent to local user.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      appBar: AppBar(
        title: const LogoAppBarTitle('Message Local User'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        // ── Message type ──
                        const Text(
                          'Message Type',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: AdminMessageType.values.map((type) {
                            final selected = _selectedType == type;
                            return ChoiceChip(
                              label: Text(type.label),
                              selected: selected,
                              onSelected: _isSending
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedType = type;
                                        if (widget.preselectedEventTitle !=
                                            null) {
                                          _subjectController.text =
                                              '${type.label}: ${widget.preselectedEventTitle}';
                                        }
                                      });
                                    },
                              selectedColor:
                                  AppPalette.ochre.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: selected
                                    ? AppPalette.ochre
                                    : AppPalette.charcoal,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ── Recipient ──
                        const Text(
                          'Recipient',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.preselectedEmail != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppPalette.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_rounded,
                                    color: AppPalette.ochre, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.preselectedEmail!,
                                    style: const TextStyle(
                                        color: AppPalette.charcoal),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _selectedEmail,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              hintText: 'Select local user...',
                            ),
                            items: _locals.map((local) {
                              final status = local['approvalStatus'] ?? '';
                              return DropdownMenuItem<String>(
                                value: local['email'],
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${local['name']} (${local['email']})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (status == 'approved') ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified_rounded,
                                          color: Colors.green, size: 16),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _isSending
                                ? null
                                : (value) =>
                                    setState(() => _selectedEmail = value),
                            validator: (_) => _selectedEmail == null
                                ? 'Please select a recipient.'
                                : null,
                          ),

                        if (widget.preselectedEventTitle != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppPalette.ochre.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppPalette.ochre.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_rounded,
                                    color: AppPalette.ochre, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Event: ${widget.preselectedEventTitle}',
                                    style: const TextStyle(
                                      color: AppPalette.ochre,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ── Subject ──
                        TextFormField(
                          controller: _subjectController,
                          enabled: !_isSending,
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
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Message ──
                        TextFormField(
                          controller: _messageController,
                          minLines: 4,
                          maxLines: 10,
                          enabled: !_isSending,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a message.';
                            }
                            if (value.trim().length < 8) {
                              return 'Message should be at least 8 characters.';
                            }
                            return null;
                          },
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                            label:
                                Text(_isSending ? 'Sending...' : 'Send Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.deepBlue,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
