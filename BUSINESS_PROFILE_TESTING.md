# Business Profile Feature - Quick Start & Testing Guide

## 🚀 Quick Start

### For Web (Already Deployed)

```bash
# Build web app
flutter build web --release

# The app is already available at:
# http://localhost:9111/#/web/landing
# http://localhost:9111/#/web/home
# http://localhost:9111/#/business/create
```

### For iOS

```bash
# Build for iOS
flutter build ios --release

# Or run on iOS simulator
flutter run -d ios

# Then archive for App Store
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -archivePath build/Runner.xcarchive archive
```

### For Android

```bash
# Build APK
flutter build apk --release

# Or build App Bundle for Google Play
flutter build appbundle --release

# Install on connected device
flutter install

# Or run on Android emulator
flutter run -d android
```

## 🧪 Testing Guide

### Manual Testing Scenarios

#### Scenario 1: Create Business Profile
```
Steps:
1. Navigate to: http://localhost:9111/#/business/create?userId=test@example.com
2. Fill in required fields:
   - Business Name: "My Restaurant"
   - Category: "Restaurant & Cafe"
   - Description: "Best food in Brisbane"
   - Address: "123 Business St, Brisbane QLD 4000"
   - Contact: "07 1234 5678"
3. Click "Choose File" for Logo and select an image
4. Click "Choose File" for Cover and select an image
5. Set business hours for Monday-Friday 09:00-17:00
6. Add social media links
7. Click "Save Profile"

Expected Result:
✅ Profile saved to Firestore
✅ Images uploaded to Firebase Storage
✅ Redirected to home page
✅ SnackBar shows "Profile saved successfully"
```

#### Scenario 2: View Business Profile
```
Steps:
1. After creating profile, copy the business ID from Firestore
2. Navigate to: http://localhost:9111/#/business/view/{businessId}
3. Verify all information displays correctly

Expected Result:
✅ Cover image displays
✅ Logo displays
✅ Business name and category visible
✅ Full description visible
✅ Contact information clickable
✅ Social media links working
✅ Business hours displayed
```

#### Scenario 3: Edit Business Profile
```
Steps:
1. Navigate to dashboard or view page
2. Click "Edit" button
3. Modify business description
4. Update a social media link
5. Save changes

Expected Result:
✅ Changes saved to Firestore
✅ Real-time update visible on view page
✅ Updated timestamp recorded
```

#### Scenario 4: Delete Business Profile
```
Steps:
1. From dashboard, click delete button
2. Confirm deletion in dialog

Expected Result:
✅ Profile removed from Firestore
✅ Images deleted from Storage
✅ Dashboard refreshes
✅ Profile no longer appears in list
```

#### Scenario 5: Search and Filter
```
Steps:
1. Go to Home page: http://localhost:9111/#/web/home
2. Type in search box: "Restaurant"
3. Select category filter: "Restaurant & Cafe"
4. Select type filter: "Both"

Expected Result:
✅ Results filtered in real-time
✅ Only matching businesses display
✅ Search is case-insensitive
✅ Filters work independently and combined
```

#### Scenario 6: Responsive Design Testing
```
Desktop Testing:
1. Open browser at full width (>768px)
2. Verify grid layout shows 3 columns
3. Sidebar visible with filters

Mobile Testing:
1. Open DevTools and set device to iPhone 12
2. Refresh page
3. Verify single column layout
4. Verify navigation buttons work
5. Verify touch targets are large enough
```

#### Scenario 7: Image Upload Validation
```
Steps:
1. Try uploading non-image file → Should fail with error
2. Try uploading large image (>50MB) → Should fail
3. Upload valid JPG → Should succeed
4. Upload valid PNG → Should succeed
5. Verify image appears in profile

Expected Result:
✅ Only image formats accepted
✅ File size validated
✅ Images display correctly after upload
```

#### Scenario 8: Form Validation
```
Test Cases:

1. Empty business name:
   Submit → Error: "Business name required"

2. Invalid phone number "123":
   Submit → Error: "Enter valid contact number"

3. Invalid website "notaurl":
   Submit → Error: "Enter valid URL"

4. Valid international phone "+61 2 1234 5678":
   Submit → Success

5. All required fields empty:
   Submit → Error on first required field
```

#### Scenario 9: Business Hours Validation
```
Steps:
1. Enable business hours for Monday
2. Set open time: 09:00
3. Set close time: 17:00
4. Close Tuesday, Wednesday, Thursday
5. Set Friday hours: 08:00-18:00
6. Save

Expected Result:
✅ Hours saved correctly
✅ Display shows correct format: "09:00 - 17:00"
✅ Display shows "Closed" for disabled days
```

#### Scenario 10: Social Media Links
```
Steps:
1. Add partial social media links
2. Leave some empty
3. Save profile

Expected Result:
✅ Only non-empty links saved
✅ View page shows only filled links
✅ Clicking links opens in new tab/app
```

## 📊 Testing Checklist

### Functionality Testing
- [ ] Create business profile with all fields
- [ ] Create business profile with minimal fields
- [ ] Read business profile (single fetch)
- [ ] Real-time stream updates on edit
- [ ] Update business profile
- [ ] Delete business profile
- [ ] Image upload (logo and cover)
- [ ] Image deletion on profile delete
- [ ] Search functionality
- [ ] Category filtering
- [ ] Type filtering (Events/Attractions)
- [ ] Form validation (all fields)
- [ ] Social media links clickable
- [ ] Contact number clickable (tel:)
- [ ] Website clickable
- [ ] Business hours display

### Platform Testing
- [ ] Web (Desktop view)
- [ ] Web (Mobile/tablet view)
- [ ] iOS simulator
- [ ] Android emulator
- [ ] Responsive breakpoint at 768px
- [ ] Touch interactions on mobile
- [ ] Scroll performance on large lists

### Performance Testing
- [ ] Form submission completes in <2s
- [ ] Image upload <5s for typical image
- [ ] Real-time updates instant (<1s)
- [ ] List rendering smooth at 60fps
- [ ] No memory leaks in streams

### Security Testing
- [ ] Non-owner cannot edit profile
- [ ] Non-owner cannot delete profile
- [ ] Public can view all profiles
- [ ] Firestore rules enforced
- [ ] Images secured in storage

### Error Handling Testing
- [ ] Network error shows graceful message
- [ ] Invalid file upload shows error
- [ ] Firestore permission denied shows error
- [ ] Navigation to non-existent profile shows error
- [ ] Failed image upload handled gracefully

## 🐛 Debugging Guide

### Common Issues

#### Issue: Images not uploading
```
Checklist:
1. Check Firebase Storage bucket name in firebase_options.dart
2. Verify storage.rules allow authenticated uploads
3. Check file size < 10MB
4. Verify file is valid image format
5. Check device has storage permissions (mobile)
```

#### Issue: Form not submitting
```
Debug steps:
1. Open DevTools Console
2. Check console for validation errors
3. Verify all required fields filled
4. Check network tab for failed requests
5. Check Firestore rules for permission issues
```

#### Issue: Real-time updates not working
```
Check:
1. Firestore connection status
2. Verify StreamBuilder listening to correct collection
3. Check user authentication status
4. Verify field permissions in security rules
5. Look for stream subscription errors
```

#### Issue: Images display as blank
```
Troubleshoot:
1. Verify image URL is valid
2. Check Firebase Storage CORS settings
3. Verify image file exists in storage
4. Check network request in DevTools
5. Look for ImageNetwork error logs
```

### Debug Logging

Enable detailed logging:

```dart
// In BusinessProfileService
void createBusinessProfile(Business business) async {
  print('Creating business: ${business.businessName}');
  print('Owner ID: ${business.ownerId}');
  
  try {
    final docRef = await _firestore.collection('businesses').add(
      business.toFirestore(),
    );
    print('✅ Business created with ID: ${docRef.id}');
  } catch (e) {
    print('❌ Error creating business: $e');
    rethrow;
  }
}
```

### Firebase Emulator (Local Development)

```bash
# Start Firestore emulator
firebase emulators:start --only firestore

# Use in app (lib/main.dart)
if (Platform.isAndroid) {
  FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
}
```

## 📈 Performance Optimization

### Current Performance Metrics

| Operation | Expected Time | Metric |
|-----------|---------------|--------|
| Create Profile | < 2s | Network + Validation + Upload |
| Image Upload | 2-5s | File size dependent |
| Fetch Single | < 500ms | Cloud Firestore |
| Fetch List | < 1s | Cloud Firestore |
| Real-time Update | < 1s | WebSocket |
| Search | < 500ms | Local filtering |

### Optimization Strategies

1. **Image Optimization**
   - Compress images before upload
   - Use WebP format for web
   - Set max file size 5MB

2. **Query Optimization**
   - Add Firestore indexes for category queries
   - Use pagination for large lists
   - Cache search results client-side

3. **UI Optimization**
   - Lazy load images
   - Use ImageCacheManager for web
   - Virtualize long lists

## 🔐 Security Checklist

- [ ] Firestore rules restrict unauthorized access
- [ ] Storage rules validate file types
- [ ] User authentication required for writes
- [ ] Owner validation on update/delete
- [ ] No sensitive data in URLs
- [ ] HTTPS enforced for all connections
- [ ] API keys restricted to mobile apps
- [ ] CORS properly configured

## 📱 Device Testing Checklist

### iOS
- [ ] Test on iPhone 12 (375x812)
- [ ] Test on iPad (1024x1366)
- [ ] Test touch interactions
- [ ] Test camera/gallery access
- [ ] Test status bar display

### Android
- [ ] Test on Pixel 4 (412x915)
- [ ] Test on tablet (768x1024)
- [ ] Test back button navigation
- [ ] Test permissions dialog
- [ ] Test keyboard interactions

### Web
- [ ] Desktop (1920x1080)
- [ ] Tablet (768x1024)
- [ ] Mobile (375x667)
- [ ] Test keyboard shortcuts
- [ ] Test browser compatibility

## 📝 Test Report Template

```markdown
# Business Profile Feature Test Report

## Build Information
- Build Date: ____
- Flutter Version: ____
- Platform: ____
- Device: ____

## Test Results

### Functionality: ✅ / ⚠️ / ❌
- Create Profile: ____
- Edit Profile: ____
- Delete Profile: ____
- View Profile: ____
- Search: ____
- Filters: ____
- Image Upload: ____

### Platform Specific: ✅ / ⚠️ / ❌
- Web Desktop: ____
- Web Mobile: ____
- iOS: ____
- Android: ____

### Issues Found
1. ____
2. ____
3. ____

## Performance Notes
- Average load time: ____
- Image upload time: ____
- List scroll performance: ____

## Recommendations
- ____
- ____

## Sign-off
Tester: ____
Date: ____
```

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] All tests passing
- [ ] Firebase Security Rules verified
- [ ] Storage CORS configured
- [ ] Error handling in place
- [ ] Logging configured
- [ ] Performance baseline met
- [ ] Documentation complete
- [ ] Backup strategy in place
- [ ] Rollback plan ready
- [ ] User communication prepared

