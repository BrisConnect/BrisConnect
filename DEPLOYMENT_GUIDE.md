# BrisConnect Firebase Deployment Guide

## 🎯 Objective
Deploy Firestore security rules and seed 27 Brisbane CBD food businesses to your Firebase project.

## ✅ Current Status
- ✓ Firestore rules updated locally with `food_businesses` collection rule
- ✓ 27 food business seed data prepared and formatted
- ✓ Automated deployment script created
- ⏳ **PENDING**: Deploy rules to Firebase

---

## 🚀 Quick Start (3 Steps)

### Step 1: Run the Automation Script
```bash
cd /Users/ibrahim_ahhoa/Documents/BrisConnect/functions
node automated_deploy.js
```

### Step 2: Deploy Rules (Choose One Method)

#### Method A: Firebase Console (⭐ Fastest - 30 seconds)
1. Open: https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules
2. Click **"Edit Rules"** button (top-right)
3. Select all content (Cmd+A)
4. Paste content from `firestore.rules` file
5. Click **"Publish"**

#### Method B: gcloud CLI
```bash
# Install if needed
brew install google-cloud-sdk

# Authenticate
gcloud auth login

# Deploy rules from project directory
cd /Users/ibrahim_ahhoa/Documents/BrisConnect
gcloud firestore:rules:deploy --project=brisconnect-68b78
```

### Step 3: Seed Food Businesses
After rules are deployed, return to the automation script:
```bash
# In the same terminal where you ran node automated_deploy.js
# Select option 2: "Seed food businesses"
```

---

## 📁 Files Reference

### Firestore Rules
**Location**: `/Users/ibrahim_ahhoa/Documents/BrisConnect/firestore.rules`

**New Rule Added**:
```firestore
match /food_businesses/{businessId} {
  allow read: if true; // Allow public read
  allow write: if isAdmin() || request.auth == null; // Dev: allow unauthenticated for seeding
}
```

### Seed Data
**Location**: `/Users/ibrahim_ahhoa/Documents/BrisConnect/functions/`

**Files**:
- `seed_brisbane_cbd_rest.js` - REST API seeding (27 businesses)
- `automated_deploy.js` - Interactive deployment assistant

**Businesses Being Seeded** (5 shown, 27 total):
1. Aria Brisbane - Fine dining Italian
2. Kintsugi - Modern Japanese
3. Red Lantern - Asian fusion
4. The Morning Alchemy - Specialty cafe
5. Osteria Semolina - Rustic Italian
... and 22 more Brisbane CBD venues

---

## 🔧 Manual Deployment (If Script Fails)

### Option 1: Browser Console
```
URL: https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules
File to paste: /Users/ibrahim_ahhoa/Documents/BrisConnect/firestore.rules
```

### Option 2: Direct REST API Call (Advanced)
```bash
curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/brisconnect-68b78/databases/(default)/securityRules?key=AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs" \
  -H "Content-Type: application/json" \
  -d @- << 'EOF'
{
  "rules": $(cat firestore.rules | jq -Rs .)
}
EOF
```

---

## 📊 What Gets Created

### Firestore Collections
- `food_businesses/{docId}` - 27 new documents with:
  - `name` (String)
  - `description` (String)
  - `address` (String)
  - `phone` (String)
  - `website` (String)
  - `cuisineTypes` (Array)
  - `imageUrl` (String)
  - `latitude` / `longitude` (Double - GPS coordinates)
  - `averageRating` (Double)
  - `reviewCount` (Integer)
  - `priceRange` (String: $, $$, $$$)
  - `createdAt` (Timestamp)

### Sample Business Record
```json
{
  "name": "Aria Brisbane",
  "description": "Fine dining Italian restaurant with contemporary flair",
  "address": "123 Eagle Street, Brisbane CBD",
  "phone": "+61 7 3221 1234",
  "website": "https://ariabrisbane.com.au",
  "cuisineTypes": ["Italian", "Fine Dining"],
  "imageUrl": "https://images.unsplash.com/photo-1504674900949-f282b92e6c8d?w=500",
  "latitude": -27.4723,
  "longitude": 153.0273,
  "averageRating": 4.8,
  "reviewCount": 127,
  "priceRange": "$$$",
  "createdAt": "2026-07-09T06:15:00.000Z"
}
```

---

## ✨ Next Steps After Seeding

### In Flutter App
1. **Home Screen** will automatically load food businesses via Firestore queries
2. **Images** from Unsplash URLs will display with error fallback icons
3. **Filter Chips** (price & rating) will work on populated data
4. **Search** functionality will find businesses by name/cuisine

### Verification
```bash
# Check Firestore Console for data
# https://console.firebase.google.com/project/brisconnect-68b78/firestore/data/food_businesses
```

---

## 🐛 Troubleshooting

### Issue: "Permission denied (403)"
**Solution**: Rules not deployed yet. Use Method A or B to deploy first.

### Issue: "Invalid rules file"
**Solution**: Ensure `firestore.rules` has correct syntax. Run: `gcloud firestore:rules:test`

### Issue: "Network timeout"
**Solution**: Your internet may be blocked. Try:
- Use Firebase Console (web-based)
- Check VPN/Proxy settings
- Wait a few minutes and retry

### Issue: Script won't run
**Solution**:
```bash
# Make executable
chmod +x /Users/ibrahim_ahhoa/Documents/BrisConnect/functions/automated_deploy.js

# Run with explicit node
node /Users/ibrahim_ahhoa/Documents/BrisConnect/functions/automated_deploy.js
```

---

## 📱 Testing in App

After seeding, verify in your Flutter app:

1. **Food Discovery Screen**
   - Should show 27 restaurants
   - Images loading from Unsplash
   - Tap on any business to see details

2. **Filter Chips**
   - Price filters ($, $$, $$$) working
   - Rating filters (4+, 4.5+, 4.8+) working
   - Filters showing correct business subsets

3. **Time-based Greeting**
   - "Good Morning/Afternoon/Evening, [Name]"
   - Subtext: "Discover Brisbane's Best Local Food"

---

## 📞 Support

**Firebase Project**: brisconnect-68b78
**Web API Key**: AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs
**Database Region**: Default (us-central1)

For issues, check:
- Firebase Console: https://console.firebase.google.com/project/brisconnect-68b78
- Firestore Security Rules: https://console.firebase.google.com/project/brisconnect-68b78/firestore/rules
- Firestore Data: https://console.firebase.google.com/project/brisconnect-68b78/firestore/data

