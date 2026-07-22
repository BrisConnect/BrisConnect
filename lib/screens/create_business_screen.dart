import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/google_places_autocomplete_service.dart';
import 'package:brisconnect/services/address_geocoding_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _contactController = TextEditingController();
  final _websiteController = TextEditingController();
  
  final BusinessProfileService _businessService = BusinessProfileService();
  final GooglePlacesAutocompleteService _placesService =
      GooglePlacesAutocompleteService();
  final AddressGeocodingService _geocodingService = AddressGeocodingService();

  static const List<String> _categories = [
    'Restaurant & Cafe',
    'Retail',
    'Service',
    'Entertainment',
    'Other',
  ];

  String _selectedCategory = 'Restaurant & Cafe';
  XFile? _selectedLogo;
  bool _isSaving = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _contactController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<Iterable<String>> _getAddressSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <String>[];
    try {
      return await _placesService.fetchBrisbaneAddressSuggestions(trimmed);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null && mounted) {
      setState(() => _selectedLogo = picked);
    }
  }

  Future<void> _createBusiness() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to create a business profile.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Validate and geocode the address
      final addressText = _addressController.text.trim();
      final latLng = await _geocodingService.geocodeAddress(addressText);

      if (latLng == null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid address. Please enter a valid Brisbane address.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Check if address is within Brisbane area
      if (!AddressGeocodingService.isWithinBrisbane(latLng.latitude, latLng.longitude)) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address must be within Brisbane. Please enter a Brisbane address.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Create business object with coordinates
      final business = Business(
        ownerId: user.uid,
        businessName: _businessNameController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        address: addressText,
        lat: latLng.latitude,
        lng: latLng.longitude,
        contactNumber: _contactController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
      );

      // Save to Firestore
      await _businessService.createBusinessProfile(business);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Show success dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Business Profile Created'),
          content: const Text(
            'Your business profile has been created successfully. You can now create events and manage your business.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to previous screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating business profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Create Business'),
        ),
        body: Center(
          child: Card(
            color: AppPalette.surface,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: AppPalette.ochre),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign In Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please sign in to create a business profile.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.local},
      deniedMessage: 'Access denied. Local users can create business profiles.',
      child: Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Create Business'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Name
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(
                      labelText: 'Business Name',
                      hintText: 'Enter your business name',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Business name is required'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Category
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedCategory = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),

                  // Address with autocomplete
                  RawAutocomplete<String>(
                    textEditingController: _addressController,
                    focusNode: _addressFocusNode,
                    optionsBuilder: (value) => _getAddressSuggestions(value.text),
                    onSelected: (selection) {
                      _addressController.text = selection;
                    },
                    fieldViewBuilder: (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Business Address',
                          hintText: 'Type business address',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Address is required'
                                : null,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width - 64,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.location_on,
                                      color: AppPalette.ochre,
                                      size: 18,
                                    ),
                                    title: Text(option),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contact Number
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      hintText: 'e.g., 0412345678',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Contact number is required'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Website (Optional)
                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website (Optional)',
                      hintText: 'e.g., https://www.example.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe your business',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Description is required'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Logo Upload
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _selectedLogo == null
                          ? 'Upload Business Logo'
                          : 'Change Logo',
                    ),
                  ),
                  if (_selectedLogo != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppPalette.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.image_rounded,
                              color: AppPalette.deepBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedLogo!.name,
                              style:
                                  const TextStyle(color: AppPalette.charcoal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppPalette.mutedText),
                            onPressed: () =>
                                setState(() => _selectedLogo = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _createBusiness,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Create Business Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
