# BrisConnect+ Business Profile Feature - Visual Documentation

## 🎨 UI Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    BrisConnect+                          │
│            Material 3 Web/Mobile App                     │
└─────────────────────────────────────────────────────────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
           WEB PLATFORM  iOS PLATFORM  ANDROID PLATFORM
           (Material 3)   (Material 3)  (Material 3)
                │           │           │
         ┌──────┴───────────┴───────────┴──────┐
         │                                     │
    ┌────▼────┐                          ┌────▼────┐
    │ Landing │─────────────────────────▶│ HomePage │
    │  Page   │   "Launch Web App"      │(Events & │
    │         │   Navigation Button      │Attractions)
    └─────────┘                          └────┬────┘
                                              │
                        ┌─────────────────────┼─────────────────────┐
                        │                     │                     │
                   ┌────▼─────┐         ┌────▼──────┐        ┌──────▼────┐
                   │  Search   │         │ Category  │        │   Type    │
                   │ Function  │         │  Filters  │        │  Filters  │
                   │(Real-time)│         │(Chips)    │        │(Radio)    │
                   └───────────┘         └────┬──────┘        └───────────┘
                                              │
                        ┌─────────────────────┼─────────────────────┐
                        │                     │                     │
                   ┌────▼──────┐        ┌────▼──────┐        ┌──────▼────┐
                   │   CREATE   │        │   VIEW    │        │    EDIT   │
                   │  Business  │        │ Business  │        │ Business  │
                   │  Profile   │        │ Profile   │        │ Profile   │
                   │   FORM     │        │ (Public)  │        │  FORM     │
                   └────┬───────┘        └───────────┘        └──────┬────┘
                        │                                            │
                   ┌────▼──────────────────────────────────────────┬┘
                   │                                               │
            ┌──────▼──────────┐                            ┌──────▼──────┐
            │   Firebase      │                            │   Firebase  │
            │   Firestore     │                            │   Storage   │
            │  (CRUD Ops)     │                            │  (Images)   │
            └─────────────────┘                            └─────────────┘
```

## 📱 Responsive Layout (768px Breakpoint)

### Desktop Layout (≥768px)
```
┌──────────────────────────────────────────────────────────┐
│ Search Bar (Full Width)                                  │
├──────────────────────────────────────────────────────────┤
│ Type Filter (Radio)      Category Filters (Chips)        │
├─────────────────┬─────────────────────────────────────────┤
│                 │  Item Card 1  │  Item Card 2  │         │
│   Type          │               │               │         │
│   Filter        ├───────────────┼───────────────┤         │
│   Sidebar       │  Item Card 3  │  Item Card 4  │         │
│                 │               │               │         │
│   Optional      ├───────────────┼───────────────┤         │
│   For           │  Item Card 5  │  Item Card 6  │         │
│   Future        │               │               │         │
│   Expansion     └───────────────┴───────────────┘         │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

### Mobile Layout (<768px)
```
┌──────────────────────────────────┐
│ Search Bar (Full Width)          │
├──────────────────────────────────┤
│ Type Filter (Radio - Compact)    │
│ Category Filters (Scrollable)    │
├──────────────────────────────────┤
│  Item Card 1                     │
│  (Full Width)                    │
├──────────────────────────────────┤
│  Item Card 2                     │
│  (Full Width)                    │
├──────────────────────────────────┤
│  Item Card 3                     │
│  (Full Width)                    │
└──────────────────────────────────┘
```

## 🏢 Business Profile Data Model

```
┌─────────────────────────────────────┐
│        Business Profile             │
├─────────────────────────────────────┤
│ • id: String (Firestore doc ID)    │
│ • ownerId: String (Auth Email)     │
│ • businessName: String              │
│ • category: String                  │
│   - Restaurant & Cafe               │
│   - Retail & Shopping               │
│   - Entertainment & Events          │
│   - Health & Wellness               │
│   - Professional Services           │
│   - Education                       │
│   - Accommodation                   │
│   - Transportation                  │
│   - Arts & Culture                  │
│   - Sports & Recreation             │
│   - Other                           │
│ • description: String               │
│ • address: String                   │
│ • contactNumber: String             │
│ • website: String? (Optional)       │
│ • logoUrl: String?                  │
│ • coverImageUrl: String?            │
│ • isVerified: bool                  │
│ • rating: double?                   │
│ • createdAt: DateTime               │
│ • updatedAt: DateTime               │
│                                     │
│ Social Media (Map)                  │
│ • Facebook: URL?                    │
│ • Instagram: URL?                   │
│ • Twitter: URL?                     │
│ • LinkedIn: URL?                    │
│ • TikTok: URL?                      │
│ • YouTube: URL?                     │
│                                     │
│ Business Hours (Per Day)            │
│ • Monday-Sunday: DayHours           │
│   - isClosed: bool                  │
│   - openTime: HH:mm                 │
│   - closeTime: HH:mm                │
└─────────────────────────────────────┘
```

## 🎯 Business Profile Form Screen Layout

### Desktop (≥768px)
```
┌─────────────────────────────────────────────────────────┐
│ BrisConnect+ | Create Business Profile                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Business Name *           │  Category *               │
│  [_____________________]    │  [Select Category ▼]      │
│                                                         │
│  Description *                                          │
│  [_____________________________________]                │
│  [_____________________________________]                │
│                                                         │
│  Address *                 │  Contact Number *         │
│  [_____________________]    │  [_____________________]   │
│                                                         │
│  Website                                                │
│  [_____________________________________]                │
│                                                         │
│  📷 Logo Image             📷 Cover Image              │
│  [Choose File]             [Choose File]               │
│                                                         │
│  🕒 Business Hours                                      │
│  ☐ Closed                                              │
│  ├─ Monday:     [08:00] - [17:00]                      │
│  ├─ Tuesday:    [08:00] - [17:00]                      │
│  ├─ Wednesday:  [08:00] - [17:00]                      │
│  ├─ Thursday:   [08:00] - [17:00]                      │
│  ├─ Friday:     [08:00] - [17:00]                      │
│  ├─ Saturday:   ☐ Closed                              │
│  └─ Sunday:     ☐ Closed                              │
│                                                         │
│  📱 Social Media Links                                 │
│  Facebook:  [_____________________]                    │
│  Instagram: [_____________________]                    │
│  Twitter:   [_____________________]                    │
│  LinkedIn:  [_____________________]                    │
│  TikTok:    [_____________________]                    │
│  YouTube:   [_____________________]                    │
│                                                         │
│  [Cancel Button]  [Save Profile Button]               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Mobile (<768px)
```
┌──────────────────────────────┐
│ Create Business Profile      │
├──────────────────────────────┤
│                              │
│ Business Name *              │
│ [____________________]        │
│                              │
│ Category *                   │
│ [Select Category ▼]          │
│                              │
│ Description *                │
│ [____________________]        │
│ [____________________]        │
│                              │
│ Address *                    │
│ [____________________]        │
│                              │
│ Contact Number *             │
│ [____________________]        │
│                              │
│ Website                      │
│ [____________________]        │
│                              │
│ 📷 Logo Image                │
│ [Choose File]                │
│                              │
│ 📷 Cover Image               │
│ [Choose File]                │
│                              │
│ 🕒 Business Hours            │
│ ☐ Closed for all days        │
│ Monday: [08:00] [17:00]      │
│ Tuesday: [08:00] [17:00]     │
│ ... (scrollable)             │
│                              │
│ 📱 Social Media               │
│ Facebook: [____________]      │
│ Instagram: [____________]     │
│ ... (scrollable)             │
│                              │
│ [Cancel]  [Save]             │
│                              │
└──────────────────────────────┘
```

## 👁️ Business Profile View Screen

### Layout (Desktop & Mobile Responsive)
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Cover Image (200px height)              │  │
│  │  [Gradient Placeholder if missing]               │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────┐  Restaurant & Cafe                          │
│  │ Logo │  Business Name                              │
│  │ 120  │  ✓ Verified (if applicable)                 │
│  │×120  │                                              │
│  └──────┘                                              │
│                                                         │
│  About Section                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │ Full business description text...                │  │
│  │ Can span multiple lines with full details       │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
│  Contact Information                                   │
│  📍 123 Business Street, Brisbane QLD 4000            │
│  ☎️  1300 BUSINESS                                     │
│  🌐 www.business.com.au                               │
│                                                         │
│  Business Hours                                        │
│  Monday-Friday:    09:00 AM - 05:00 PM                │
│  Saturday:         10:00 AM - 03:00 PM                │
│  Sunday:           Closed                              │
│                                                         │
│  Follow Us                                             │
│  [f] [in] [tw] [yt] [tiktok] [insta]                  │
│                                                         │
│  [✏️ Edit Profile]  (owner only)                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🎬 My Business Dashboard (Owner View)

### Desktop Grid Layout
```
┌─────────────────────────────────────────────────────────┐
│ My Businesses                    [+ New Business]        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │  Cover Image     │  │  Cover Image     │           │
│  │  (150px)         │  │  (150px)         │           │
│  ├──────────────────┤  ├──────────────────┤           │
│  │ 🏪 Business 1   │  │ 🏪 Business 2   │           │
│  │ Restaurant      │  │ Retail Shop     │           │
│  │ ✓ Verified      │  │ ⏳ Pending       │           │
│  │                 │  │                  │           │
│  │ [👁] [✏️] [🗑]  │  │ [👁] [✏️] [🗑]   │           │
│  └──────────────────┘  └──────────────────┘           │
│                                                         │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │  Cover Image     │  │  Cover Image     │           │
│  │  (150px)         │  │  (150px)         │           │
│  ├──────────────────┤  ├──────────────────┤           │
│  │ 🏪 Business 3   │  │ 🏪 Business 4   │           │
│  │ Arts & Culture  │  │ Professional Svc│           │
│  │ ✓ Verified      │  │ ⏳ Pending       │           │
│  │                 │  │                  │           │
│  │ [👁] [✏️] [🗑]  │  │ [👁] [✏️] [🗑]   │           │
│  └──────────────────┘  └──────────────────┘           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Mobile Single Column Layout
```
┌──────────────────────────────┐
│ My Businesses                │
├──────────────────────────────┤
│                              │
│  [+ New Business]            │
│                              │
│  ┌──────────────────────────┐│
│  │  Cover Image (150px)     ││
│  ├──────────────────────────┤│
│  │ 🏪 Business 1           ││
│  │ Restaurant              ││
│  │ ✓ Verified              ││
│  │                          ││
│  │ [👁] [✏️] [🗑]          ││
│  └──────────────────────────┘│
│                              │
│  ┌──────────────────────────┐│
│  │  Cover Image (150px)     ││
│  ├──────────────────────────┤│
│  │ 🏪 Business 2           ││
│  │ Retail Shop             ││
│  │ ⏳ Pending               ││
│  │                          ││
│  │ [👁] [✏️] [🗑]          ││
│  └──────────────────────────┘│
│                              │
│  ┌──────────────────────────┐│
│  │  Cover Image (150px)     ││
│  ├──────────────────────────┤│
│  │ 🏪 Business 3           ││
│  │ Arts & Culture          ││
│  │ ✓ Verified              ││
│  │                          ││
│  │ [👁] [✏️] [🗑]          ││
│  └──────────────────────────┘│
│                              │
└──────────────────────────────┘
```

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Web/Mobile App                    │
└──────────────────────────────────┬──────────────────────────────┘
                                   │
                ┌──────────────────┼──────────────────┐
                │                  │                  │
         ┌──────▼──────┐   ┌──────▼──────┐  ┌───────▼──────┐
         │   Screens   │   │  Services   │  │   Models     │
         ├─────────────┤   ├─────────────┤  ├──────────────┤
         │• Form       │   │• Business   │  │• Business    │
         │• View       │   │  Profile    │  │• DayHours    │
         │• Dashboard  │   │  Service    │  │• Constants   │
         └─────────────┘   └──────┬──────┘  └──────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
            ┌──────▼────┐  ┌──────▼────┐  ┌────▼──────┐
            │ Firebase  │  │ Firebase  │  │ ImagePicker
            │ Firestore │  │ Storage   │  │ URLLauncher
            │ (CRUD)    │  │ (Images)  │  │ (Web APIs)
            └───────────┘  └───────────┘  └───────────┘
                    │              │              │
                    └──────────────┼──────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │   Firebase Backend           │
                    │  (brisconnect-68b78)         │
                    ├──────────────────────────────┤
                    │ • Firestore Collections      │
                    │ • Security Rules             │
                    │ • Cloud Storage Buckets      │
                    │ • Real-time Listeners        │
                    └──────────────────────────────┘
```

## 🔐 Security & Access Control

```
┌────────────────────────────────────────────────────────┐
│              Firestore Security Rules                  │
├────────────────────────────────────────────────────────┤
│                                                        │
│ ✅ PUBLIC READ                                        │
│    • Any user can view all business profiles          │
│    • No authentication required                       │
│                                                        │
│ ✅ OWNER CREATE/UPDATE/DELETE                         │
│    • ownerId == request.auth.token.email              │
│    • Only business owner can modify                   │
│                                                        │
│ ✅ ADMIN VERIFICATION                                 │
│    • Admins can verify businesses                     │
│    • Set isVerified = true                            │
│                                                        │
│ ✅ IMAGE STORAGE                                      │
│    • business_logos/{businessId}_{timestamp}.jpg      │
│    • business_covers/{businessId}_cover_{ts}.jpg      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

## 📊 Data Flow

```
┌─────────────┐
│  User        │
│  Interface  │
└──────┬──────┘
       │ User Action (Create/Edit)
       ▼
┌─────────────────────────────┐
│  BusinessProfileFormScreen  │
│  (Validation & Collection)  │
└──────┬──────────────────────┘
       │ Form Submission
       ▼
┌─────────────────────────────┐
│  Image Upload (Optional)    │
│  • ImagePicker selects file │
│  • Upload to Firebase Store │
│  • Get download URL         │
└──────┬──────────────────────┘
       │ URLs received
       ▼
┌─────────────────────────────┐
│  BusinessProfileService     │
│  • createBusinessProfile()  │
│  • updateBusinessProfile()  │
└──────┬──────────────────────┘
       │ Document write operation
       ▼
┌─────────────────────────────┐
│  Firebase Firestore         │
│  /businesses/{docId}        │
│  - ownerId validation       │
│  - Timestamp generation     │
│  - Document created/updated │
└──────┬──────────────────────┘
       │ Real-time listener
       ▼
┌─────────────────────────────┐
│  StreamBuilder (View Page)  │
│  • Fetches updated data     │
│  • Re-renders UI            │
│  • Shows verification badge │
└──────────────────────────────┘
```

## ✨ Material 3 Design System

### Color Palette
```
┌─────────────────────────────────────────────────────┐
│  Primary Colors                                     │
├─────────────────────────────────────────────────────┤
│ 🟠 Ochre (Primary)        #D4A574                   │
│ 🟡 Gold (Secondary)        #C4A050                  │
│ 🔵 Deep Blue (Headings)   #1a3a52                  │
│ ⚫ Charcoal (Body Text)    #1a1a1a                  │
│ ⚪ Surface/Card            #FFFDF8                  │
│ 🟤 Background              #F7F4ED                  │
└─────────────────────────────────────────────────────┘
```

### Material 3 Components
- **Buttons**: ElevatedButton (Primary), TextButton (Secondary)
- **Cards**: Elevated with shadow and rounded corners
- **Text Fields**: OutlineInputBorder with validation
- **Chips**: FilterChip for categories, status badges
- **Dialogs**: Material dialog for confirmations
- **AppBar**: Elevated with custom color

## 📱 Cross-Platform Compatibility

```
┌──────────────────────────────────────────────────────┐
│            Single Codebase - All Platforms          │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ✅ Web                                              │
│     • Material 3 responsive design                   │
│     • 768px breakpoint (mobile/desktop)              │
│     • Modern browser support                         │
│     • Deployed at localhost:9111                     │
│                                                      │
│  ✅ iOS                                              │
│     • iOS 15+ support                                │
│     • Material 3 Cupertino adaptation               │
│     • Touch-optimized UI                             │
│     • Firebase integrated                            │
│                                                      │
│  ✅ Android                                          │
│     • Material 3 native design                       │
│     • Android 5.0+ support                           │
│     • Touch-optimized UI                             │
│     • Firebase integrated                            │
│                                                      │
│  📦 Shared Dependencies                              │
│     • cloud_firestore ^6.1.3                         │
│     • firebase_storage ^13.2.0                       │
│     • image_picker ^1.2.1                            │
│     • url_launcher ^6.3.2                            │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## 🎯 Feature Completeness Checklist

```
✅ Business Profile CRUD
   ✅ Create new business profile
   ✅ Read single business profile
   ✅ Update business profile
   ✅ Delete business profile

✅ Form Validation
   ✅ Required field validation
   ✅ Phone number regex validation
   ✅ URL validation
   ✅ Business hours logic validation

✅ Image Management
   ✅ Logo upload to Firebase Storage
   ✅ Cover image upload to Firebase Storage
   ✅ Image URL retrieval
   ✅ Image deletion on profile delete

✅ Business Information
   ✅ Basic info (name, category, description)
   ✅ Contact details (address, phone, website)
   ✅ Social media links (6 platforms)
   ✅ Business hours (7 days, open/close times)
   ✅ Verification status
   ✅ Rating support

✅ User Interface
   ✅ Create business form (with image upload)
   ✅ Edit business form (with existing data)
   ✅ View business profile (public)
   ✅ My Business dashboard (owner)
   ✅ Responsive mobile/desktop layout
   ✅ Material 3 design system

✅ Real-time Features
   ✅ Real-time updates via StreamBuilder
   ✅ Live profile modifications
   ✅ Instant verification badge updates

✅ Security
   ✅ Owner-only access (update/delete)
   ✅ Public read access
   ✅ Admin verification capability
   ✅ Firestore security rules
```

## 🚀 Deployment Status

| Platform | Status | Location | Build Command |
|----------|--------|----------|----------------|
| **Web** | ✅ Live | localhost:9111 | `flutter build web --release` |
| **iOS** | ✅ Ready | - | `flutter build ios --release` |
| **Android** | ✅ Ready | - | `flutter build apk --release` |

