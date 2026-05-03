import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/screens/location_settings_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:permission_handler/permission_handler.dart';

class LocalSettingsScreen extends StatefulWidget {
  const LocalSettingsScreen({super.key});

  @override
  State<LocalSettingsScreen> createState() => _LocalSettingsScreenState();
}

class _LocalSettingsScreenState extends State<LocalSettingsScreen> {
  late bool _locationAccessEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _locationAccessEnabled = LocalAuth.isLocationAccessEnabled();
  }

  Future<void> _persistSettings({
    bool? locationAccessEnabled,
  }) async {
    setState(() => _isSaving = true);

    final success = await LocalAuth.setGeneralAppSettings(
      locationAccessEnabled: locationAccessEnabled,
    );

    if (mounted) {
      setState(() {
        if (success && locationAccessEnabled != null) {
          _locationAccessEnabled = locationAccessEnabled;
        }
        _isSaving = false;
      });
    }

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save settings. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleLocationAccess(bool value) async {
    if (!value) {
      await _persistSettings(locationAccessEnabled: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location access disabled for app features.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      await _persistSettings(locationAccessEnabled: true);
      return;
    }

    final requested = await Permission.locationWhenInUse.request();
    final granted = requested.isGranted;
    await _persistSettings(locationAccessEnabled: granted);

    if (!mounted) return;
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission granted.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Location permission was not granted. You can enable it in system settings.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = LocalAuth.currentLocal;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Location Radius'),
      ),
      body: local == null
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
                const _SectionLabel('Location Permissions'),
                const SizedBox(height: 8),
                Card(
                  color: AppPalette.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppPalette.border),
                  ),
                  child: SwitchListTile(
                    value: _locationAccessEnabled,
                    onChanged: _isSaving ? null : _toggleLocationAccess,
                    title: const Text(
                      'Enable Location Access',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Allow nearby recommendations and map-aware features.',
                    ),
                    secondary: const Icon(
                      Icons.location_on_outlined,
                      color: AppPalette.deepBlue,
                    ),
                    activeThumbColor: AppPalette.deepBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: AppPalette.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppPalette.border),
                  ),
                  child: ListTile(
                    title: const Text(
                      'Location Settings',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Set your search radius for events and attractions.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationSettingsScreen.local(),
                        ),
                      );
                    },
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
