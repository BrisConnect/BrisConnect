import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:brisconnect/models/simple_event.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class EventMapScreen extends StatefulWidget {
  final List<SimpleEvent> events;

  /// When provided, the map centres on this event and pre-selects its marker.
  final SimpleEvent? focusedEvent;

  const EventMapScreen({
    super.key,
    required this.events,
    this.focusedEvent,
  });

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  late GoogleMapController _mapController;
  SimpleEvent? _selectedEvent;

  // Default centre: Brisbane CBD
  static const LatLng _brisbaneCenter = LatLng(-27.4698, 153.0251);

  LatLng get _initialCenter {
    final f = widget.focusedEvent;
    if (f != null) return LatLng(f.lat, f.lng);
    return _brisbaneCenter;
  }

  double get _initialZoom => widget.focusedEvent != null ? 15.0 : 13.5;

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.focusedEvent;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers() {
    return widget.events
        .asMap()
        .entries
        .map((entry) => _buildMarker(entry.value, entry.key))
        .toSet();
  }

  Marker _buildMarker(SimpleEvent event, int index) {
    final isSelected = _selectedEvent?.title == event.title;
    return Marker(
      markerId: MarkerId('event-$index'),
      position: LatLng(event.lat, event.lng),
      infoWindow: InfoWindow(
        title: event.title,
        snippet: event.location,
      ),
      onTap: () {
        setState(() => _selectedEvent = event);
        _mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(event.lat, event.lng)),
        );
      },
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isSelected ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Event Locations'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: _initialZoom,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (_) => setState(() => _selectedEvent = null),
            markers: _buildMarkers(),
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
          ),

          // Info card shown when a marker is tapped
          if (_selectedEvent != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: AppPalette.surface,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppPalette.ochre),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedEvent!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedEvent!.location,
                              style: const TextStyle(
                                  fontSize: 13, color: AppPalette.mutedText),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _selectedEvent = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

