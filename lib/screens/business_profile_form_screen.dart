import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:image_picker/image_picker.dart';

/// Form screen for creating and editing business profiles
class BusinessProfileFormScreen extends StatefulWidget {
  final Business? existingBusiness; // Null for create, populated for edit
  final String userId;

  const BusinessProfileFormScreen({
    super.key,
    this.existingBusiness,
    required this.userId,
  });

  @override
  State<BusinessProfileFormScreen> createState() => _BusinessProfileFormScreenState();
}

class _BusinessProfileFormScreenState extends State<BusinessProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessProfileService = BusinessProfileService();
  final _imagePicker = ImagePicker();

  // Form fields
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _websiteController;
  late String _selectedCategory;

  // Social media links
  final Map<String, TextEditingController> _socialMediaControllers = {};

  // Opening hours
  final Map<String, DayHours> _businessHours = {};

  // Images
  String? _logoUrl;
  String? _coverImageUrl;
  XFile? _selectedLogoFile;
  XFile? _selectedCoverFile;
  Uint8List? _selectedLogoBytes;
  Uint8List? _selectedCoverBytes;

  bool _isLoading = false;
  bool _isEditMode = false;

  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingBusiness != null;
    _initializeControllers();
    _initializeBusinessHours();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.existingBusiness?.businessName ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingBusiness?.description ?? '');
    _addressController = TextEditingController(text: widget.existingBusiness?.address ?? '');
    _contactController =
        TextEditingController(text: widget.existingBusiness?.contactNumber ?? '');
    _websiteController = TextEditingController(text: widget.existingBusiness?.website ?? '');
    _selectedCategory = widget.existingBusiness?.category ?? businessCategories.first;
    _logoUrl = widget.existingBusiness?.logoUrl;
    _coverImageUrl = widget.existingBusiness?.coverImageUrl;

    // Initialize social media controllers
    for (final platform in socialMediaPlatforms) {
      _socialMediaControllers[platform] =
          TextEditingController(text: widget.existingBusiness?.socialMedia?[platform] ?? '');
    }
  }

  void _initializeBusinessHours() {
    if (widget.existingBusiness?.businessHours != null) {
      _businessHours.addAll(widget.existingBusiness!.businessHours!.hours);
    } else {
      // Default hours for all days
      for (final day in _weekDays) {
        _businessHours[day] = DayHours(
          isClosed: false,
          openTime: '09:00',
          closeTime: '17:00',
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _websiteController.dispose();
    for (final controller in _socialMediaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectLogoImage() async {
    final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedLogoFile = image;
        _selectedLogoBytes = bytes;
      });
    }
  }

  Future<void> _selectCoverImage() async {
    final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 1280, maxHeight: 720);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedCoverFile = image;
        _selectedCoverBytes = bytes;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images if new files selected
      if (_selectedLogoFile != null) {
        _logoUrl = await _businessProfileService.uploadLogoImage(
          businessId: widget.existingBusiness?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
          filePath: _selectedLogoFile!.path,
        );
      }

      if (_selectedCoverFile != null) {
        _coverImageUrl = await _businessProfileService.uploadCoverImage(
          businessId: widget.existingBusiness?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
          filePath: _selectedCoverFile!.path,
        );
      }

      // Create or update business
      final business = Business(
        id: widget.existingBusiness?.id,
        ownerId: widget.userId,
        businessName: _nameController.text.trim(),
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        contactNumber: _contactController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        socialMedia: _getSocialMediaMap(),
        logoUrl: _logoUrl,
        coverImageUrl: _coverImageUrl,
        businessHours: BusinessHours(hours: _businessHours),
        createdAt: widget.existingBusiness?.createdAt,
        updatedAt: DateTime.now(),
        isVerified: widget.existingBusiness?.isVerified ?? false,
      );

      if (_isEditMode) {
        await _businessProfileService.updateBusinessProfile(business);
        if (mounted) _showSuccessDialog('Business profile updated successfully!');
      } else {
        final businessId = await _businessProfileService.createBusinessProfile(business);
        if (mounted) _showSuccessDialog('Business profile created successfully!', businessId: businessId);
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _getSocialMediaMap() {
    final result = <String, String>{};
    for (final platform in socialMediaPlatforms) {
      final url = _socialMediaControllers[platform]?.text.trim() ?? '';
      if (url.isNotEmpty) {
        result[platform] = url;
      }
    }
    return result;
  }

  void _showSuccessDialog(String message, {String? businessId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(_isEditMode ? 'Profile Updated' : 'Profile Created'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (businessId != null) {
                // Navigate to view page after creating
                Navigator.pushReplacementNamed(
                  context,
                  '/business/view',
                  arguments: businessId,
                );
              } else {
                Navigator.pop(context); // Go back to previous screen after editing
              }
            },
            child: Text(businessId != null ? 'View Profile' : 'Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Business Profile' : 'Create Business Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Name
                  _buildTextField(
                    controller: _nameController,
                    label: 'Business Name',
                    hint: 'Enter your business name',
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Business name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Category Dropdown
                  _buildCategoryDropdown(),
                  const SizedBox(height: 20),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Describe your business',
                    maxLines: 4,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Address
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Enter business address',
                    validator: (value) => value?.isEmpty ?? true ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Contact Number
                  _buildTextField(
                    controller: _contactController,
                    label: 'Contact Number',
                    hint: 'Enter contact number',
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Contact number is required';
                      if (!RegExp(r'^[0-9\-\+\s\(\)]{10,}$').hasMatch(value!)) {
                        return 'Enter a valid contact number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Website
                  _buildTextField(
                    controller: _websiteController,
                    label: 'Website (Optional)',
                    hint: 'https://example.com',
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasScheme ||
                          (!uri.scheme.startsWith('http') && !uri.scheme.startsWith('https'))) {
                        return 'Enter a valid URL starting with http:// or https://';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Social Media Links
                  _buildSocialMediaSection(),
                  const SizedBox(height: 24),

                  // Business Hours
                  _buildBusinessHoursSection(),
                  const SizedBox(height: 24),

                  // Logo Upload
                  _buildImageUploadSection(
                    title: 'Business Logo',
                    currentImageUrl: _logoUrl,
                    selectedFile: _selectedLogoFile,
                    selectedBytes: _selectedLogoBytes,
                    onTap: _selectLogoImage,
                  ),
                  const SizedBox(height: 20),

                  // Cover Image Upload
                  _buildImageUploadSection(
                    title: 'Cover Image',
                    currentImageUrl: _coverImageUrl,
                    selectedFile: _selectedCoverFile,
                    selectedBytes: _selectedCoverBytes,
                    onTap: _selectCoverImage,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isEditMode ? 'Update Profile' : 'Create Profile'),
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: businessCategories
              .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
          decoration: const InputDecoration(hintText: 'Select a category'),
        ),
      ],
    );
  }

  Widget _buildSocialMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Social Media Links (Optional)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...socialMediaPlatforms.map((platform) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _socialMediaControllers[platform],
              decoration: InputDecoration(
                hintText: 'https://${platform.toLowerCase()}.com/yourprofile',
                labelText: platform,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBusinessHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Hours', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ..._weekDays.map((day) {
          final hours = _businessHours[day];
          if (hours == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDayHoursRow(day, hours),
          );
        }),
      ],
    );
  }

  Widget _buildDayHoursRow(String day, DayHours hours) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(day),
        ),
        Expanded(
          child: CheckboxListTile(
            title: const Text('Closed'),
            value: hours.isClosed,
            onChanged: (value) {
              setState(() {
                _businessHours[day] = DayHours(isClosed: value ?? false);
              });
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (!hours.isClosed)
          Expanded(
            child: GestureDetector(
              onTap: () => _pickTime(day, isOpen: true),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(text: hours.openTime),
                  decoration: const InputDecoration(labelText: 'Open'),
                  readOnly: true,
                ),
              ),
            ),
          ),
        if (!hours.isClosed) const SizedBox(width: 8),
        if (!hours.isClosed)
          Expanded(
            child: GestureDetector(
              onTap: () => _pickTime(day, isOpen: false),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(text: hours.closeTime),
                  decoration: const InputDecoration(labelText: 'Close'),
                  readOnly: true,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickTime(String day, {required bool isOpen}) async {
    final hours = _businessHours[day];
    if (hours == null) return;
    final timeStr = (isOpen ? hours.openTime : hours.closeTime) ?? '09:00';
    final parts = timeStr.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _businessHours[day] = DayHours(
          isClosed: hours.isClosed,
          openTime: isOpen ? formatted : hours.openTime,
          closeTime: isOpen ? hours.closeTime : formatted,
        );
      });
    }
  }

  Widget _buildImageUploadSection({
    required String title,
    required String? currentImageUrl,
    required XFile? selectedFile,
    required Uint8List? selectedBytes,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: InkWell(
              onTap: onTap,
              child: selectedBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(selectedBytes, fit: BoxFit.cover),
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : currentImageUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(currentImageUrl, fit: BoxFit.cover),
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Tap to upload $title',
                                style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text('JPG or PNG recommended',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
            ),
          ),
        ),
      ],
    );
  }
}
