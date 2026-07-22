import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/screens/business_profile_detail_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class BusinessMapScreen extends StatefulWidget {
  final List<Business> businesses;
  final Business? focusedBusiness;

  const BusinessMapScreen({
    super.key,
    required this.businesses,
    this.focusedBusiness,
  });

  @override
  State<BusinessMapScreen> createState() => _BusinessMapScreenState();
}

class _BusinessMapScreenState extends State<BusinessMapScreen> {
  late GoogleMapController _mapController;
  Business? _selectedBusiness;

  // Default centre: Brisbane CBD
  static const LatLng _brisbaneCenter = LatLng(-27.4698, 153.0251);

  LatLng get _initialCenter {
    final f = widget.focusedBusiness;
    if (f != null && f.lat != null && f.lng != null) {
      return LatLng(f.lat!, f.lng!);
    }
    return _brisbaneCenter;
  }

  double get _initialZoom => widget.focusedBusiness != null ? 15.0 : 13.5;

  @override
  void initState() {
    super.initState();
    _selectedBusiness = widget.focusedBusiness;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers() {
    return widget.businesses
        .asMap()
        .entries
        .where((entry) => entry.value.lat != null && entry.value.lng != null)
        .map((entry) => _buildMarker(entry.value, entry.key))
        .toSet();
  }

  Marker _buildMarker(Business business, int index) {
    final isSelected = _selectedBusiness?.id == business.id;
    return Marker(
      markerId: MarkerId('business-${business.id}'),
      position: LatLng(business.lat!, business.lng!),
      infoWindow: InfoWindow(
        title: business.businessName,
        snippet: business.address,
        onTap: () => _showBusinessSheet(business),
      ),
      onTap: () {
        setState(() => _selectedBusiness = business);
        _mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(business.lat!, business.lng!)),
        );
      },
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isSelected ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueBlue,
      ),
    );
  }

  void _showBusinessSheet(Business business) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        color: AppPalette.background,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.businessName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business.category,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      business.address,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openDirections(business),
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BusinessProfileDetailScreen(businessId: business.id!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('View Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(Business business) async {
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${business.lat},${business.lng}';
    try {
      await launchUrl(
        Uri.parse(mapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open directions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBusinesses =
        widget.businesses.where((b) => b.lat != null && b.lng != null).toList();

    if (filteredBusinesses.isEmpty) {
      return Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Business Locations'),
          backgroundColor: AppPalette.ochre,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'No businesses found with location data.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Business Locations'),
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
            onTap: (_) => setState(() => _selectedBusiness = null),
            markers: _buildMarkers(),
            myLocationButtonEnabled: true,
          ),
          if (_selectedBusiness != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBusiness!.businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedBusiness!.address,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () =>
                                _openDirections(_selectedBusiness!),
                            icon: const Icon(Icons.directions),
                            label: const Text('Directions'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppPalette.ochre,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BusinessProfileDetailScreen(
                                        businessId: _selectedBusiness!.id!,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info),
                            label: const Text('Profile'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppPalette.ochre,
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
