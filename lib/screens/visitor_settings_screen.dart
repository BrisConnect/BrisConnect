import 'package:flutter/material.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/l10n/app_localizations.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:permission_handler/permission_handler.dart';

class VisitorSettingsScreen extends StatefulWidget {
  const VisitorSettingsScreen({super.key});

  @override
  State<VisitorSettingsScreen> createState() => _VisitorSettingsScreenState();
}

class _VisitorSettingsScreenState extends State<VisitorSettingsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late bool _locationAccessEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _locationAccessEnabled = VisitorAuth.isLocationAccessEnabled();
  }

  Future<void> _persistSettings({
    bool? locationAccessEnabled,
  }) async {
    setState(() => _isSaving = true);

    final success = await VisitorAuth.setGeneralAppSettings(
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
        SnackBar(
          content: Text(l10n.couldNotSaveSettings),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleLocationAccess(bool value) async {
    if (!value) {
      await _persistSettings(locationAccessEnabled: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.locationAccessDisabled),
          duration: const Duration(seconds: 2),
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
        SnackBar(
          content: Text(l10n.locationPermissionGranted),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.locationPermissionNotGranted,
          ),
          action: SnackBarAction(
            label: l10n.openSettings,
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 4),
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
        title: LogoAppBarTitle(l10n.locationSettings),
      ),
      body: visitor == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.pleaseLoginToViewSettings,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _SectionLabel(l10n.locationPermissions),
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
                    title: Text(
                      l10n.enableLocationAccess,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      l10n.allowNearbyMapFeatures,
                    ),
                    secondary: const Icon(
                      Icons.location_on_outlined,
                      color: AppPalette.deepBlue,
                    ),
                    activeThumbColor: AppPalette.deepBlue,
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel(l10n.about),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.aboutDescription,
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.versionLabel('1.0.0'),
                          style: const TextStyle(
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
