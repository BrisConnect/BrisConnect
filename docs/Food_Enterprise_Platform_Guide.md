# Food Enterprise Platform - Implementation Guide

## Overview
BrisConnect is now a food enterprise visibility platform that empowers small and medium food businesses with real-time crowd reporting, ratings, and reviews.

## Firestore Database Schema

### 1. Businesses Collection
```
/businesses/{businessId}
├── name: string
├── description: string
├── address: string
├── phone: string (optional)
├── website: string (optional)
├── cuisineTypes: array<string> (e.g., ["Italian", "Vegan", "Fast Food"])
├── imageUrl: string (optional)
├── latitude: number (optional)
├── longitude: number (optional)
├── averageRating: number (auto-calculated from reviews)
├── reviewCount: number (auto-calculated)
├── operatingHours: string (optional, e.g., "9:00 AM - 10:00 PM")
├── createdAt: timestamp
└── updatedAt: timestamp
```

### 2. Reviews Subcollection
```
/businesses/{businessId}/reviews/{reviewId}
├── businessId: string
├── userId: string (Firebase Auth UID)
├── userName: string (from user profile)
├── rating: number (1-5 stars)
├── comment: string
├── createdAt: timestamp
└── helpfulCount: number
```

### 3. Crowd Reports Collection
```
/crowd_reports/{reportId}
├── businessId: string (or eventId - generic)
├── userId: string (Firebase Auth UID)
├── level: string ("low", "moderate", "high")
├── weight: number (1, 2, or 3)
├── timestamp: timestamp
```

## Features Implemented

### 1. **Crowd Level Reporting** ✅
- **Location**: Available on food business detail page
- **Functionality**: 
  - Visitors report Low/Moderate/High crowd levels
  - 30-minute cooldown per user to prevent spam
  - Real-time weighted average calculation
  - Color-coded display (Green=Low, Yellow=Moderate, Orange=High)

### 2. **Business Ratings & Reviews** ✅
- **Location**: Available on food business detail page
- **Features**:
  - 5-star rating system
  - Text comment required
  - Real-time review submission
  - Automatic average rating calculation
  - Review list with user name and date
  - Helpful count tracking (future enhancement)

### 3. **Food Business Discovery** ✅
- **Location**: New screen accessible from main navigation
- **Features**:
  - Browse all food businesses
  - Search by name, cuisine type, or description
  - Sort by rating, newest, or relevance
  - View business cards with image, name, cuisines, address, and rating
  - Click to view full business details

### 4. **Business Detail Page** ✅
- **Displays**:
  - Hero image
  - Business name and cuisine types
  - Rating summary with review count
  - Full description
  - Contact info (address, phone, website, hours)
  - Crowd level reporting widget
  - Ratings and reviews section

## Core Services

### FoodBusinessService
- `getAllBusinesses()` - Stream of all businesses sorted by rating
- `searchBusinesses(query)` - Search businesses by name/cuisine/description
- `getBusinessById(id)` - Get single business details
- `getBusinessesByCuisine(type)` - Filter by cuisine type
- `getTopRatedBusinesses(limit)` - Get top-rated businesses
- `getNewBusinesses(limit)` - Get newly added businesses

### BusinessRatingsService
- `submitReview()` - Submit new rating and review
- `getBusinessReviews()` - Stream of reviews for a business
- `getAverageRating()` - Calculate current average
- `hasUserReviewed()` - Check if user already reviewed
- `deleteReview()` - Remove user's review (owner only)

### CrowdReportService
- `canSubmitReport()` - Check 30-minute cooldown
- `submitReport()` - Record crowd level report
- `watchCrowdStatus()` - Real-time crowd status stream

## UI Components

### FoodBusinessDiscoveryScreen
Main discovery interface with search and business listing

### FoodBusinessDetailScreen
Complete business profile with all sections integrated

### BusinessReviewsWidget
Rating submission form and review list display

### CrowdReportWidget
Crowd level reporting (reused from event platform, now generic)

## Security Considerations

### Firestore Rules (Recommended)
```
// Public read access for businesses
match /businesses/{document=**} {
  allow read: if true;
}

// Users can create and edit their own reviews
match /businesses/{businessId}/reviews/{reviewId} {
  allow read: if true;
  allow create: if request.auth != null;
  allow update, delete: if request.auth.uid == resource.data.userId;
}

// Crowd reports accessible by all
match /crowd_reports/{document=**} {
  allow read: if true;
  allow create: if request.auth != null;
}
```

## Next Steps for Backend

1. **Seed Data**: Add sample food businesses to Firestore
2. **Admin Interface**: Create admin dashboard for business management
3. **Image Hosting**: Setup Cloud Storage for business images
4. **Analytics**: Track popular searches and businesses
5. **Notifications**: Alert businesses about new reviews
6. **Loyalty Program**: Implement rewards for reviews/reporting

## Testing Checklist

- [ ] Navigate to food business discovery screen
- [ ] Search for a business
- [ ] View business detail page
- [ ] Submit a crowd report
- [ ] Submit a rating and review
- [ ] Verify real-time updates
- [ ] Check 30-minute crowd report cooldown
- [ ] Test with multiple users

## Files Created

```
lib/
├── models/
│   ├── food_business.dart
│   └── business_review.dart
├── services/
│   ├── food_business_service.dart
│   └── business_ratings_service.dart
├── screens/
│   ├── food_business_discovery_screen.dart
│   └── food_business_detail_screen.dart
└── widgets/
    └── business_reviews_widget.dart
```
