# Food Business Navigation Integration Guide

## Overview
The BrisConnect app has been updated to include a complete food enterprise visibility platform. This guide explains how to access the new food business features from within the running app.

---

## 🗺️ Navigation Structure

### Mobile App Navigation
The app uses a **Bottom Navigation Bar** with 5 tabs:

| Index | Tab | Icon | Screen | Route |
|-------|-----|------|--------|-------|
| 0 | Home | home | Discover feed | `/` |
| 1 | Map | map_outlined | Map view | `/map` |
| 2 | Saved | favorite_border_rounded | Saved items | (internal) |
| 3 | Profile | person_outline_rounded | User profile | (internal) |
| **4** | **Food** | **restaurant_outlined** | **Food Business Discovery** | `/food-businesses` |

### Web Navigation
Web routes are configured in `main.dart`:
- `/web/home` - Web home page
- `/web/admin` - Web admin dashboard
- `/food-businesses` - Food discovery (accessible from both mobile & web)

---

## 📱 Mobile App Access

### Method 1: Via Bottom Navigation Bar (Easiest)
1. Open the BrisConnect app
2. Tap the **Food** tab (restaurant icon) in the bottom navigation
3. Browse food businesses with real-time search

### Method 2: Via Route Navigation (Programmatic)
```dart
Navigator.of(context).pushNamed('/food-businesses');
```

### Method 3: Direct Screen Navigation (Programmatic)
```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (context) => const FoodBusinessDiscoveryScreen(),
));
```

---

## 🍽️ Food Business Features

### Discovery Screen (`/food-businesses`)
**Location:** Bottom navigation tab 4  
**Features:**
- Search food businesses by name, cuisine, description
- Real-time search results with live filtering
- Business cards with:
  - Hero image with fallback placeholder
  - Business name
  - Cuisine types (chips)
  - Address
  - Average rating with review count
  - Tap to view detail

**File:** `lib/screens/food_business_discovery_screen.dart`

### Detail Screen (`/food-business/detail`)
**Accessed:** Tap any business card from discovery screen  
**Features:**

1. **Business Information**
   - Hero image gallery
   - Name, cuisine types, about section
   - Contact details (phone, address, website, hours)

2. **Crowd Level Reporting** 
   - Report venue crowding: Low / Moderate / High
   - 30-minute cooldown per user
   - Real-time crowd status display
   - Color-coded: Green (Low), Yellow (Moderate), Orange (High)
   - **Widget:** `CrowdReportWidget`

3. **Ratings & Reviews**
   - View all reviews sorted newest-first
   - Submit 1-5 star ratings with comments
   - See average rating and total review count
   - Duplicate submission prevention
   - **Widget:** `BusinessReviewsWidget`

**File:** `lib/screens/food_business_detail_screen.dart`

---

## 🔧 Code Integration Reference

### File Structure
```
lib/
├── screens/
│   ├── food_business_discovery_screen.dart    # Browse businesses
│   ├── food_business_detail_screen.dart       # View business details
│   └── visitor_portal_screen.dart             # MODIFIED: Added tab 4
│
├── widgets/
│   ├── business_reviews_widget.dart           # Ratings/reviews UI
│   ├── crowd_report_widget.dart               # Crowd reporting UI
│   └── business_card.dart                     # Discovery card
│
├── services/
│   ├── food_business_service.dart             # Business queries
│   ├── business_ratings_service.dart          # Rating/review CRUD
│   └── crowd_report_service.dart              # Crowd reporting logic
│
└── models/
    ├── food_business.dart                     # Business data model
    └── business_review.dart                   # Review data model
```

### Route Registration (main.dart)
Routes are defined in the `routes` map:
```dart
routes: {
  // ... existing routes ...
  '/food-businesses': (_) => const FoodBusinessDiscoveryScreen(),
  '/food-business/detail': (context) {
    final businessId = ModalRoute.of(context)?.settings.arguments as String?;
    return FoodBusinessDetailScreen(
      businessId: businessId ?? '',
    );
  },
},
```

### Tab Integration (visitor_portal_screen.dart)
The 5th tab is added to `VisitorPortalScreen`:

**Bottom Navigation Item (Index 4):**
```dart
BottomNavigationBarItem(
  icon: const Padding(
    padding: EdgeInsets.only(bottom: 4),
    child: Icon(Icons.restaurant_outlined),
  ),
  activeIcon: Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(Icons.restaurant_rounded),
  ),
  label: 'Food',
),
```

**IndexedStack Child (Index 4):**
```dart
SafeArea(child: FoodBusinessDiscoveryScreen()),
```

---

## 🔐 Firestore Security & Permissions

### Collections & Access
| Collection | Document | Read | Create | Update | Delete |
|------------|----------|------|--------|--------|--------|
| `businesses` | food business | Public | Admin | Admin | Admin |
| `businesses/{id}/reviews` | review | Public | Auth user | Auth user* | Auth user* |
| `businesses/{id}/crowd_reports` | crowd report | Public | Auth user | - | - |

*Only own records

### Security Rules Template
```javascript
// Firestore security rules (firebase.rules)
match /businesses/{businessId} {
  allow read: if true;  // Public read
  allow write: if request.auth != null && request.auth.token.admin == true;
  
  match /reviews/{reviewId} {
    allow read: if true;  // Public read
    allow create: if request.auth != null;
    allow update, delete: if request.auth.uid == resource.data.userId;
  }
  
  match /crowd_reports/{reportId} {
    allow read: if true;  // Public read
    allow create: if request.auth != null;
  }
}
```

---

## 📊 Data Models

### FoodBusiness
```dart
class FoodBusiness {
  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String? website;
  final List<String> cuisineTypes;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final double averageRating;      // 0-5, auto-calculated
  final int reviewCount;
  final Map<String, dynamic>? operatingHours;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### BusinessReview
```dart
class BusinessReview {
  final String id;
  final String businessId;
  final String userId;
  final String userName;
  final double rating;              // 1-5
  final String comment;
  final DateTime createdAt;
  final int helpfulCount;
}
```

### Crowd Report
```dart
class CrowdReport {
  final String id;
  final String businessId;          // Previously eventId
  final String userId;
  final String crowdLevel;          // 'Low', 'Moderate', 'High'
  final DateTime timestamp;
}
```

---

## 🚀 Testing Checklist

- [ ] Bottom navigation "Food" tab appears and is clickable
- [ ] FoodBusinessDiscoveryScreen loads with available businesses
- [ ] Search filtering works in real-time
- [ ] Tapping a business card navigates to detail screen
- [ ] Detail screen displays hero image, info, contact details
- [ ] Crowd reporting widget shows with 3 buttons (Low/Moderate/High)
- [ ] Can submit crowd report and see cooldown timer
- [ ] Rating submission form appears in reviews section
- [ ] Can submit 1-5 star rating with comment
- [ ] Reviews display sorted newest-first
- [ ] Average rating updates after submission
- [ ] Crowd level colors display correctly (Green/Yellow/Orange)

---

## 🐛 Troubleshooting

### Food tab not appearing?
- **Cause:** App not hot-reloaded after changes
- **Fix:** Hot reload (`r` in terminal) or hot restart (`R`)

### No businesses showing?
- **Cause:** Firestore `/businesses` collection is empty
- **Fix:** See "Seeding Test Data" section below

### Crowd report not saving?
- **Cause:** User not authenticated
- **Fix:** Ensure logged in as visitor user (not anonymous)

### Reviews not updating average rating?
- **Cause:** `_updateBusinessRating()` not called automatically
- **Fix:** This is automatic when review submitted via `BusinessRatingsService`

---

## 🌱 Seeding Test Data

Create sample businesses in Firestore:

**Firestore path:** `/businesses/{businessId}`

```json
{
  "name": "City Espresso",
  "description": "Premium coffee roastery in the heart of Brisbane",
  "address": "Level 2, 111 Queen Street, Brisbane QLD 4000",
  "phone": "(07) 3210 1234",
  "website": "https://cityespresso.com.au",
  "cuisineTypes": ["Coffee", "Cafe"],
  "imageUrl": "https://example.com/coffee.jpg",
  "latitude": -27.4738,
  "longitude": 151.2125,
  "averageRating": 4.7,
  "reviewCount": 23,
  "operatingHours": {
    "Mon-Fri": "6:00 AM - 6:00 PM",
    "Sat": "8:00 AM - 5:00 PM",
    "Sun": "Closed"
  },
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-07-09T14:30:00Z"
}
```

Create reviews at: `/businesses/{businessId}/reviews/{reviewId}`

```json
{
  "businessId": "city_espresso",
  "userId": "user123",
  "userName": "Sarah M.",
  "rating": 5,
  "comment": "Best coffee in Brisbane! Friendly staff and amazing atmosphere.",
  "createdAt": "2024-07-05T12:00:00Z",
  "helpfulCount": 12
}
```

---

## 📖 Service API Reference

### FoodBusinessService
```dart
// Get all businesses sorted by rating
Stream<List<FoodBusiness>> getAllBusinesses()

// Search by name, cuisine, or description
Stream<List<FoodBusiness>> searchBusinesses(String query)

// Get single business
Future<FoodBusiness?> getBusinessById(String businessId)

// Filter by cuisine type
Stream<List<FoodBusiness>> getBusinessesByCuisine(String cuisineType)

// Get top-rated businesses
Stream<List<FoodBusiness>> getTopRatedBusinesses({int limit = 10})

// Get newly added businesses
Stream<List<FoodBusiness>> getNewBusinesses({int limit = 5})
```

### BusinessRatingsService
```dart
// Submit or update review (auto-updates business rating)
Future<void> submitReview(
  String businessId,
  double rating,
  String comment,
)

// Get all reviews for business
Stream<List<BusinessReview>> getBusinessReviews(String businessId)

// Calculate current average
Future<double> getAverageRating(String businessId)

// Check if user already reviewed
Future<bool> hasUserReviewed(String businessId)

// Delete own review
Future<void> deleteReview(String businessId, String reviewId)
```

### CrowdReportService
```dart
// Submit crowd level report (Low/Moderate/High)
Future<void> submitCrowdReport(
  String businessId,
  String crowdLevel,
)

// Get current crowd status
Stream<String> getCrowdStatus(String businessId)

// Check cooldown status (30 minutes)
Future<bool> canSubmitReport(String businessId)

// Get time until next report allowed
Future<Duration> getTimeUntilNextReport(String businessId)
```

---

## 🎨 Styling & Theme

### Color Scheme
- **Low crowd:** `#00D084` (Green)
- **Moderate crowd:** `#FFB900` (Yellow)
- **High crowd:** `#E85C0D` (Orange)
- **Primary brand:** `#C7931D` (Ochre)

### Typography
- **Font family:** Inter (via google_fonts)
- **App name color:** Ochre
- **Card radius:** 16dp
- **Button radius:** 30dp

---

## 📝 Notes

- **Real-time updates:** All lists use Firestore snapshots() for live updates
- **Offline support:** Mobile app has unlimited cache (Firestore persistence enabled)
- **Weighted averaging:** Crowd levels calculated with weights: Low=1, Moderate=2, High=3 over 2-hour window
- **30-min cooldown:** Per-user crowd reporting limit (Firestore queries for auth, SharedPreferences for anonymous)
- **Image fallback:** Placeholder shown if business image unavailable

---

## 📞 Support & Questions

- **Integration issues?** Check that imports are added: `import 'package:brisconnect/screens/food_business_discovery_screen.dart';`
- **Routes not working?** Verify main.dart route map includes `/food-businesses` entry
- **Hot reload not showing new tab?** Try hot restart: `R` in terminal
- **Firestore errors?** Check Firebase console for security rule violations or auth issues

---

**Last Updated:** July 9, 2026  
**Version:** 1.0  
**Status:** ✅ Integrated & Live
