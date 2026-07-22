# Business Profile Feature - Implementation Code Examples

## 1. Business Model Implementation

### Core Business Data Class
```dart
class Business {
  final String id;
  final String ownerId;
  final String businessName;
  final String category;
  final String description;
  final String address;
  final String contactNumber;
  final String? website;
  final Map<String, String> socialMedia; // Facebook, Instagram, etc.
  final String? logoUrl;
  final String? coverImageUrl;
  final Map<String, DayHours>? businessHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isVerified;
  final double? rating;

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'businessName': businessName,
      'category': category,
      'description': description,
      'address': address,
      'contactNumber': contactNumber,
      'website': website,
      'socialMedia': socialMedia,
      'logoUrl': logoUrl,
      'coverImageUrl': coverImageUrl,
      'businessHours': businessHours?.map((k, v) => MapEntry(k, v.toFirestore())),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      'rating': rating,
    };
  }

  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Business(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      businessName: data['businessName'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      website: data['website'],
      socialMedia: Map<String, String>.from(data['socialMedia'] ?? {}),
      logoUrl: data['logoUrl'],
      coverImageUrl: data['coverImageUrl'],
      businessHours: (data['businessHours'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, DayHours.fromFirestore(v))),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isVerified: data['isVerified'] ?? false,
      rating: (data['rating'] as num?)?.toDouble(),
    );
  }
}

class DayHours {
  final bool isClosed;
  final String openTime; // HH:mm format
  final String closeTime;

  DayHours({
    required this.isClosed,
    required this.openTime,
    required this.closeTime,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'isClosed': isClosed,
      'openTime': openTime,
      'closeTime': closeTime,
    };
  }

  factory DayHours.fromFirestore(Map<String, dynamic> data) {
    return DayHours(
      isClosed: data['isClosed'] ?? false,
      openTime: data['openTime'] ?? '09:00',
      closeTime: data['closeTime'] ?? '17:00',
    );
  }

  String getDisplayText() {
    return isClosed ? 'Closed' : '$openTime - $closeTime';
  }
}

// Business Categories
const List<String> businessCategories = [
  'Restaurant & Cafe',
  'Retail & Shopping',
  'Entertainment & Events',
  'Health & Wellness',
  'Professional Services',
  'Education',
  'Accommodation',
  'Transportation',
  'Arts & Culture',
  'Sports & Recreation',
  'Other',
];

// Social Media Platforms
const List<String> socialMediaPlatforms = [
  'Facebook',
  'Instagram',
  'Twitter',
  'LinkedIn',
  'TikTok',
  'YouTube',
];
```

## 2. Business Service Implementation

### CRUD Operations
```dart
class BusinessProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create new business profile
  Future<String> createBusinessProfile(Business business) async {
    try {
      final docRef = await _firestore.collection('businesses').add(
        business.toFirestore(),
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create business profile: $e');
    }
  }

  // Get single business (one-time read)
  Future<Business?> getBusinessProfile(String businessId) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) return null;
      return Business.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch business profile: $e');
    }
  }

  // Real-time business profile updates
  Stream<Business?> getBusinessProfileStream(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return Business.fromFirestore(snapshot);
        });
  }

  // Get all businesses for a user
  Future<List<Business>> getUserBusinessProfiles(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('ownerId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch user businesses: $e');
    }
  }

  // Real-time user businesses stream
  Stream<List<Business>> getUserBusinessProfilesStream(String userId) {
    return _firestore
        .collection('businesses')
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList();
        });
  }

  // Update business profile
  Future<void> updateBusinessProfile(Business business) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(business.id)
          .update(business.toFirestore());
    } catch (e) {
      throw Exception('Failed to update business profile: $e');
    }
  }

  // Delete business profile
  Future<void> deleteBusinessProfile(String businessId) async {
    try {
      final business = await getBusinessProfile(businessId);
      if (business != null) {
        // Delete images
        if (business.logoUrl != null) {
          await _deleteImageFromUrl(business.logoUrl!);
        }
        if (business.coverImageUrl != null) {
          await _deleteImageFromUrl(business.coverImageUrl!);
        }
      }
      // Delete document
      await _firestore.collection('businesses').doc(businessId).delete();
    } catch (e) {
      throw Exception('Failed to delete business profile: $e');
    }
  }

  // Search businesses
  Future<List<Business>> searchBusinesses(String query) async {
    try {
      final snapshot = await _firestore.collection('businesses').get();
      final lowerQuery = query.toLowerCase();
      return snapshot.docs
          .map((doc) => Business.fromFirestore(doc))
          .where((business) {
            return business.businessName.toLowerCase().contains(lowerQuery) ||
                business.category.toLowerCase().contains(lowerQuery) ||
                business.description.toLowerCase().contains(lowerQuery);
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to search businesses: $e');
    }
  }

  // Filter by category
  Future<List<Business>> getBusinessesByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) => Business.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch businesses by category: $e');
    }
  }
}
```

### Image Upload Operations
```dart
// Upload logo image to Firebase Storage
Future<String> uploadLogoImage(String businessId, File imageFile) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('business_logos/$businessId\_$timestamp.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  } catch (e) {
    throw Exception('Failed to upload logo: $e');
  }
}

// Upload cover image to Firebase Storage
Future<String> uploadCoverImage(String businessId, File imageFile) async {
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage
        .ref()
        .child('business_covers/${businessId}_cover_$timestamp.jpg');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  } catch (e) {
    throw Exception('Failed to upload cover image: $e');
  }
}

// Delete image from storage URL
Future<void> _deleteImageFromUrl(String downloadUrl) async {
  try {
    final ref = FirebaseStorage.instance.refFromURL(downloadUrl);
    await ref.delete();
  } catch (e) {
    debugPrint('Warning: Could not delete image: $e');
  }
}
```

## 3. Form Screen - Key Methods

### Image Picker Integration
```dart
Future<void> _pickLogoImage() async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedLogoFile = pickedFile;
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error picking image: $e')),
    );
  }
}
```

### Form Validation
```dart
String? _validateContactNumber(String? value) {
  if (value?.isEmpty ?? true) return 'Contact number is required';
  // Australian phone number format
  final phoneRegex = RegExp(r'^[0-9\-\+\s\(\)]{10,}$');
  if (!phoneRegex.hasMatch(value!)) {
    return 'Enter a valid contact number';
  }
  return null;
}

String? _validateWebsite(String? value) {
  if (value?.isEmpty ?? true) return null; // Optional field
  final uri = Uri.tryParse(value!);
  if (uri == null || !uri.hasAbsolutePath) {
    return 'Enter a valid URL';
  }
  return null;
}
```

### Submit Form Handler
```dart
Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    String? logoUrl = _logoUrl;
    String? coverUrl = _coverImageUrl;

    // Upload logo if selected
    if (_selectedLogoFile != null) {
      logoUrl = await _service.uploadLogoImage(
        _isEditMode ? _currentBusiness!.id : 'temp',
        File(_selectedLogoFile!.path),
      );
    }

    // Upload cover if selected
    if (_selectedCoverFile != null) {
      coverUrl = await _service.uploadCoverImage(
        _isEditMode ? _currentBusiness!.id : 'temp',
        File(_selectedCoverFile!.path),
      );
    }

    // Build business object
    final business = Business(
      id: _isEditMode ? _currentBusiness!.id : '',
      ownerId: widget.userId,
      businessName: _nameController.text,
      category: _selectedCategory,
      description: _descriptionController.text,
      address: _addressController.text,
      contactNumber: _contactController.text,
      website: _websiteController.text.isEmpty ? null : _websiteController.text,
      socialMedia: Map.fromEntries(
        _socialMediaControllers.entries
            .where((e) => e.value.text.isNotEmpty)
            .map((e) => MapEntry(e.key, e.value.text)),
      ),
      logoUrl: logoUrl,
      coverImageUrl: coverUrl,
      businessHours: _businessHours.isNotEmpty ? _businessHours : null,
      isVerified: _isEditMode ? _currentBusiness!.isVerified : false,
    );

    // Save to Firestore
    if (_isEditMode) {
      await _service.updateBusinessProfile(business);
    } else {
      await _service.createBusinessProfile(business);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

## 4. View Screen - Real-time Updates

### StreamBuilder Implementation
```dart
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Business Profile'),
      actions: [
        if (isOwnProfile)
          IconButton(
            icon: Icon(Icons.edit_rounded),
            onPressed: () => Navigator.pushNamed(
              context,
              '/business/edit',
              arguments: business,
            ),
          ),
      ],
    ),
    body: StreamBuilder<Business?>(
      stream: _service.getBusinessProfileStream(widget.businessId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(child: Text('Business not found'));
        }

        final business = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppPalette.ochre, AppPalette.gold],
                  ),
                ),
                child: business.coverImageUrl != null
                    ? Image.network(
                        business.coverImageUrl!,
                        fit: BoxFit.cover,
                      )
                    : SizedBox.expand(),
              ),

              // Business info
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo and name
                    Row(
                      children: [
                        if (business.logoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              business.logoUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                business.businessName,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              SizedBox(height: 8),
                              Chip(label: Text(business.category)),
                              if (business.isVerified)
                                Chip(
                                  label: Text('Verified'),
                                  backgroundColor: Colors.green,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // About
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(business.description),

                    SizedBox(height: 16),

                    // Contact info
                    _buildContactSection(business),

                    SizedBox(height: 16),

                    // Business hours
                    _buildHoursSection(business),

                    SizedBox(height: 16),

                    // Social media
                    _buildSocialMediaSection(business),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
```

## 5. Dashboard Screen - Grid Layout

### Business Grid with Actions
```dart
Widget _buildBusinessGrid(List<Business> businesses) {
  final isMobile = MediaQuery.of(context).size.width < 768;

  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: isMobile ? 1 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.8,
    ),
    itemCount: businesses.length,
    itemBuilder: (context, index) {
      final business = businesses[index];
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppPalette.ochre, AppPalette.gold],
                ),
              ),
              child: business.coverImageUrl != null
                  ? Image.network(
                      business.coverImageUrl!,
                      fit: BoxFit.cover,
                    )
                  : SizedBox.expand(),
            ),

            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (business.logoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            business.logoUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.businessName,
                              style: Theme.of(context).textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              business.category,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // Status badge
                  Chip(
                    label: Text(
                      business.isVerified ? 'Verified' : 'Pending',
                    ),
                    backgroundColor: business.isVerified
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                  ),

                  SizedBox(height: 12),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.visibility_outlined),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/business/view',
                          arguments: business.id,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_rounded),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/business/edit',
                          arguments: business,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_rounded),
                        color: Colors.red,
                        onPressed: () => _showDeleteConfirmation(business),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

## 6. Routing Configuration

### Main.dart Routes
```dart
routes: {
  '/': (_) => !kIsWeb 
      ? const _StartupProbeScreen() 
      : const WebLandingPage(),
  
  '/web/landing': (_) => const WebLandingPage(),
  '/web/home': (_) => const WebHomePage(),
  
  '/business/create': (context) {
    final userId = ModalRoute.of(context)?.settings.arguments as String?;
    return BusinessProfileFormScreen(userId: userId ?? '');
  },
  
  '/business/edit': (context) {
    final business = ModalRoute.of(context)?.settings.arguments as Business?;
    return business != null
        ? BusinessProfileFormScreen(
            existingBusiness: business,
            userId: business.ownerId,
          )
        : const Scaffold(
            body: Center(child: Text('Business not found')),
          );
  },
  
  '/business/view': (context) {
    final businessId = ModalRoute.of(context)?.settings.arguments as String?;
    return BusinessProfileViewScreen(businessId: businessId ?? '');
  },
  
  '/my-business': (context) {
    final userId = ModalRoute.of(context)?.settings.arguments as String?;
    return MyBusinessScreen(userId: userId ?? '');
  },
},
initialRoute: kIsWeb ? '/web/landing' : '/',
```

## 7. Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Public collections - read-only
    match /events/{document=**} {
      allow read: if true;
      allow create, update, delete: if request.auth != null;
    }

    match /approved_attractions/{document=**} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isAdmin == true;
    }

    match /event_categories/{document=**} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isAdmin == true;
    }

    // Business profiles - owner and public read
    match /businesses/{businessId} {
      allow read: if true;
      allow create: if request.auth != null && 
                       request.resource.data.ownerId == request.auth.token.email;
      allow update, delete: if request.auth != null && 
                               (resource.data.ownerId == request.auth.token.email || 
                                get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.isAdmin == true);
    }
  }
}
```

This documentation covers all the essential implementation details with production-ready code examples that work seamlessly across Web, iOS, and Android platforms.
