import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen.visitor({super.key}) : isLocal = false;

  const LocationSettingsScreen.local({super.key}) : isLocal = true;

  final bool isLocal;

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  late bool _useCurrentLocation;
  late int _locationRadiusKm;
  bool _isSaving = false;

  bool get _isLoggedIn {
    return widget.isLocal
        ? LocalAuth.currentLocal != null
        : VisitorAuth.currentVisitor != null;
  }

  @override
  void initState() {
    super.initState();
    _useCurrentLocation = widget.isLocal
        ? LocalAuth.currentLocal?.useCurrentLocation ?? true
        : VisitorAuth.currentVisitor?.useCurrentLocation ?? true;
    _locationRadiusKm = widget.isLocal
        ? LocalAuth.currentLocal?.locationRadiusKm ?? 20
        : VisitorAuth.currentVisitor?.locationRadiusKm ?? 20;
  }

  Future<void> _persistSettings({
    bool? useCurrentLocation,
    int? locationRadiusKm,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final success = widget.isLocal
        ? await LocalAuth.setLocationSettings(
            useCurrentLocation: useCurrentLocation,
            locationRadiusKm: locationRadiusKm,
          )
        : await VisitorAuth.setLocationSettings(
            useCurrentLocation: useCurrentLocation,
            locationRadiusKm: locationRadiusKm,
          );

    if (!mounted) return;

    setState(() {
      if (success) {
        if (useCurrentLocation != null) {
          _useCurrentLocation = useCurrentLocation;
        }
        if (locationRadiusKm != null) {
          _locationRadiusKm = locationRadiusKm;
        }
      }
      _isSaving = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save location settings. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _radiusLabel(int km) {
    return '$km km';
  }

  @override
  Widget build(BuildContext context) {
    const radiusOptions = [5, 10, 20, 50, 100];

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Location Settings'),
      ),
      body: !_isLoggedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Log in to configure your location preferences.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Use Current Location toggle
                Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Use Current Location',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppPalette.charcoal,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Enable location access to filter events and attractions by distance',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppPalette.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _useCurrentLocation && !_isSaving,
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(
                                          () => _useCurrentLocation = value);
                                      _persistSettings(
                                          useCurrentLocation: value);
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Radius selection
                Card(
                  color: AppPalette.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Search Radius',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select how far from your location to search',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppPalette.mutedText,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: _locationRadiusKm,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppPalette.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppPalette.mutedText,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _locationRadiusKm = value);
                                    _persistSettings(locationRadiusKm: value);
                                  }
                                },
                          items: radiusOptions
                              .map((km) => DropdownMenuItem<int>(
                                    value: km,
                                    child: Text(_radiusLabel(km)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Info section
                Card(
                  color: AppPalette.surface.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: AppPalette.mutedText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location filtering helps you discover events and attractions nearby. Your current location is only used for filtering - it\'s never stored.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppPalette.mutedText,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
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
