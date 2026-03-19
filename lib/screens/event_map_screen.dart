import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Event Locations'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onTap: (_, __) => setState(() => _selectedEvent = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.brisconnect',
              ),
              MarkerLayer(
                markers: widget.events
                    .map((event) => _buildMarker(event))
                    .toList(),
              ),
            ],
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

  Marker _buildMarker(SimpleEvent event) {
    final isSelected = _selectedEvent?.title == event.title;
    return Marker(
      point: LatLng(event.lat, event.lng),
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => setState(() => _selectedEvent = event),
        child: Icon(
          Icons.location_pin,
          color: isSelected ? AppPalette.gold : AppPalette.ochre,
          size: isSelected ? 48 : 36,
        ),
      ),
    );
  }
}

