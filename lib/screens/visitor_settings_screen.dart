import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/services/visitor_notification_service.dart';

class VisitorSettingsScreen extends StatefulWidget {
  const VisitorSettingsScreen({super.key});

  @override
  State<VisitorSettingsScreen> createState() => _VisitorSettingsScreenState();
}

class _VisitorSettingsScreenState extends State<VisitorSettingsScreen> {
  late bool _notificationsEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = VisitorAuth.areNotificationsEnabled();
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _isSaving = true);
    
    final success = await VisitorAuth.setNotificationsEnabled(value);
    
    if (mounted) {
      setState(() {
        if (success) {
          _notificationsEnabled = value;
        }
        _isSaving = false;
      });
    }

    if (success && value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event notifications enabled. You will receive reminders for interested events.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (success && !value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event notifications disabled.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save preference. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitor = VisitorAuth.currentVisitor;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.deepBlue,
        foregroundColor: Colors.white,
        title: const LogoAppBarTitle('Settings'),
      ),
      body: visitor == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Please log in to view settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.charcoal,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Notifications Section ─────────────────────────────
                const _SectionLabel('Notifications'),
                const SizedBox(height: 8),
                Card(
                  color: AppPalette.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppPalette.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppPalette.deepBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.notifications_rounded,
                                color: AppPalette.deepBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Event Reminders',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.charcoal,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _notificationsEnabled
                                        ? 'You will receive reminders for events you are interested in'
                                        : 'You will not receive event reminders',
                                    style: const TextStyle(
                                      color: AppPalette.mutedText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _notificationsEnabled,
                              onChanged: _isSaving ? null : _toggleNotifications,
                              activeColor: AppPalette.deepBlue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppPalette.ochre.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_rounded,
                                color: AppPalette.ochre,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'You will receive a reminder notification 24 hours before each event you are interested in.',
                                  style: TextStyle(
                                    color: AppPalette.charcoal,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── About Section ──────────────────────────────────
                const _SectionLabel('About'),
                const SizedBox(height: 8),
                Card(
                  color: AppPalette.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppPalette.border),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BrisConnect',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your guide to cultural experiences in Brisbane during the summer season.',
                          style: TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppPalette.mutedText,
      ),
    );
  }
}
