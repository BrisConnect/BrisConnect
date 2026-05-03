import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen.visitor({super.key}) : isLocal = false;

  const NotificationSettingsScreen.local({super.key}) : isLocal = true;

  final bool isLocal;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late bool _notificationsEnabled;
  late bool _eventRemindersEnabled;
  late String _reminderTiming;
  late bool _eventUpdatesEnabled;
  late bool _nearbyEventsEnabled;
  late bool _recommendedEventsEnabled;
  late bool _emailNotificationsEnabled;
  bool _isSaving = false;

  bool get _isLoggedIn => widget.isLocal
      ? LocalAuth.currentLocal != null
      : VisitorAuth.currentVisitor != null;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.isLocal
        ? LocalAuth.areNotificationsEnabled()
        : VisitorAuth.areNotificationsEnabled();
    _eventRemindersEnabled = widget.isLocal
        ? LocalAuth.areEventRemindersEnabled()
        : VisitorAuth.areEventRemindersEnabled();
    _reminderTiming = widget.isLocal
        ? LocalAuth.getReminderTiming()
        : VisitorAuth.getReminderTiming();
    _eventUpdatesEnabled = widget.isLocal
        ? (LocalAuth.currentLocal?.eventUpdatesEnabled ?? true)
        : (VisitorAuth.currentVisitor?.eventUpdatesEnabled ?? true);
    _nearbyEventsEnabled = widget.isLocal
        ? (LocalAuth.currentLocal?.nearbyEventsEnabled ?? true)
        : (VisitorAuth.currentVisitor?.nearbyEventsEnabled ?? true);
    _recommendedEventsEnabled = widget.isLocal
        ? (LocalAuth.currentLocal?.recommendedEventsEnabled ?? true)
        : (VisitorAuth.currentVisitor?.recommendedEventsEnabled ?? true);
    _emailNotificationsEnabled = widget.isLocal
        ? true
        : VisitorAuth.isEmailNotificationsEnabled();
  }

  Future<void> _persist({
    bool? notificationsEnabled,
    bool? eventRemindersEnabled,
    String? reminderTiming,
    bool? eventUpdatesEnabled,
    bool? nearbyEventsEnabled,
    bool? recommendedEventsEnabled,
    bool? emailNotificationsEnabled,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final success = widget.isLocal
        ? await LocalAuth.setNotificationSettings(
            notificationsEnabled: notificationsEnabled,
            eventRemindersEnabled: eventRemindersEnabled,
            reminderTiming: reminderTiming,
            eventUpdatesEnabled: eventUpdatesEnabled,
            nearbyEventsEnabled: nearbyEventsEnabled,
            recommendedEventsEnabled: recommendedEventsEnabled,
          )
        : await VisitorAuth.setNotificationSettings(
            notificationsEnabled: notificationsEnabled,
            eventRemindersEnabled: eventRemindersEnabled,
            reminderTiming: reminderTiming,
            eventUpdatesEnabled: eventUpdatesEnabled,
            nearbyEventsEnabled: nearbyEventsEnabled,
            recommendedEventsEnabled: recommendedEventsEnabled,
            emailNotificationsEnabled: emailNotificationsEnabled,
          );

    if (!mounted) return;

    setState(() {
      if (success) {
        _notificationsEnabled = notificationsEnabled ?? _notificationsEnabled;
        _eventRemindersEnabled =
            eventRemindersEnabled ?? _eventRemindersEnabled;
        _reminderTiming = reminderTiming ?? _reminderTiming;
        _eventUpdatesEnabled = eventUpdatesEnabled ?? _eventUpdatesEnabled;
        _nearbyEventsEnabled = nearbyEventsEnabled ?? _nearbyEventsEnabled;
        _recommendedEventsEnabled =
            recommendedEventsEnabled ?? _recommendedEventsEnabled;
        _emailNotificationsEnabled =
            emailNotificationsEnabled ?? _emailNotificationsEnabled;
      }
      _isSaving = false;
    });
  }

  String _reminderTimingLabel(String value) {
    switch (value) {
      case '1h':
        return 'Current: 1 hour before';
      case '24h':
        return 'Current: 24 hours before';
      case '48h':
        return 'Current: 48 hours before';
      default:
        return 'Current: $value';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: !_isLoggedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Please log in to manage notification settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Control your event updates in one place',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.mutedText,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  title: 'Enable All Notifications',
                  value: _notificationsEnabled,
                  onChanged: (value) => _persist(notificationsEnabled: value),
                ),
                _buildSwitchTile(
                  title: 'Event Reminders',
                  value: _eventRemindersEnabled,
                  onChanged: (value) => _persist(eventRemindersEnabled: value),
                ),
                Card(
                  color: AppPalette.surface,
                  child: ListTile(
                    title: const Text('Reminder Timing'),
                    subtitle: Text(_reminderTimingLabel(_reminderTiming)),
                    trailing: DropdownButton<String>(
                      value: _reminderTiming,
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                _persist(reminderTiming: value);
                              }
                            },
                      items: const [
                        DropdownMenuItem(value: '1h', child: Text('1 hour')),
                        DropdownMenuItem(
                          value: '24h',
                          child: Text('24 hours'),
                        ),
                        DropdownMenuItem(
                          value: '48h',
                          child: Text('48 hours'),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildSwitchTile(
                  title: 'Event Updates',
                  value: _eventUpdatesEnabled,
                  onChanged: (value) => _persist(eventUpdatesEnabled: value),
                ),
                _buildSwitchTile(
                  title: 'Nearby Events',
                  value: _nearbyEventsEnabled,
                  onChanged: (value) => _persist(nearbyEventsEnabled: value),
                ),
                _buildSwitchTile(
                  title: 'Recommended Events',
                  value: _recommendedEventsEnabled,
                  onChanged: (value) =>
                      _persist(recommendedEventsEnabled: value),
                ),
                if (!widget.isLocal)
                  _buildSwitchTile(
                    title: 'Email Notifications',
                    value: _emailNotificationsEnabled,
                    onChanged: (value) =>
                        _persist(emailNotificationsEnabled: value),
                  ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      color: AppPalette.surface,
      child: SwitchListTile(
        value: value,
        onChanged: _isSaving ? null : onChanged,
        title: Text(title),
        activeThumbColor: AppPalette.deepBlue,
      ),
    );
  }
}