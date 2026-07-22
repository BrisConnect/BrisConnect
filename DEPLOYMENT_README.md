# BrisConnect - Automated Firestore Deployment

## TL;DR (2 minutes total)

The rules need to be deployed to Firebase **once**. After that, you can seed data anytime.

### Step 1: One-Time Setup (1 minute)

1. Open: https://console.firebase.google.com/project/brisconnect-68b78/settings/serviceaccounts/adminsdk
2. Click **"Generate New Private Key"** button
3. A JSON file downloads → Save it as: `/Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json`

### Step 2: Deploy & Seed (< 1 minute)

Run this command:

```bash
cd /Users/ibrahim_ahhoa/Documents/BrisConnect
GOOGLE_APPLICATION_CREDENTIALS="$PWD/service-account-key.json" node functions/deploy_fully_automated.js
```

**That's it!** The script will:
- ✅ Deploy Firestore security rules
- ✅ Verify deployment succeeded
- ✅ Seed all 27 Brisbane food businesses  
- ✅ Show success confirmation

---

## What's happening behind the scenes?

The rules file includes this permission for the food_businesses collection:

```firestore
match /food_businesses/{businessId} {
  allow read: if true;  // Anyone can read
  allow write: if isAdmin() || request.auth == null;  // Dev: allow unauthenticated for seeding
}
```

This allows:
- **Public read** - Anyone can view food business data
- **Unauthenticated write** - Our seed script can upload the initial data

---

## Verification

After running the script, you can verify the data was seeded:

1. Go to: https://console.firebase.google.com/project/brisconnect-68b78/firestore/data/food_businesses
2. You should see 27 documents (one for each Brisbane restaurant/cafe)

Or in your Flutter app, run:

```bash
flutter run -d "iPhone 17"
```

And the home screen should display the food businesses with images and details.

---

## If something goes wrong

**Q: "Operation not permitted" error?**
- Make sure you saved the service account key to the exact path: `/Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json`

**Q: "PERMISSION_DENIED" from Firestore?**
- The service account key hasn't been loaded. Try running the command again with full path:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/Users/ibrahim_ahhoa/Documents/BrisConnect/service-account-key.json"
node /Users/ibrahim_ahhoa/Documents/BrisConnect/functions/deploy_fully_automated.js
```

**Q: Still 403 errors after deployment?**
- The rules might not have deployed successfully. Run the verification steps above to check.

---

## The service account key - is it secure?

The service account key file grants full access to your Firebase project. **IMPORTANT:**
- ✅ DO add it to `.gitignore` (already set in the project)
- ✅ DO NOT commit it to git
- ✅ DO NOT share it publicly
- The key file in this project is for **development only**

---

## Next Steps

Once deployed, you can:

1. **Test in the app**: Run `flutter run -d "iPhone 17"` and see food businesses displayed
2. **Add more data**: Modify `seed_brisbane_cbd_rest.js` with new restaurants
3. **Update rules**: Edit `firestore.rules` and run the deploy command again

