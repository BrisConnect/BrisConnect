#!/usr/bin/env python3
import json

# Comprehensive Punjabi translations for visitor-facing UI
punjabi_translations = {
    # Core actions
    "save": "ਸੰਭਾਲੋ",
    "cancel": "ਰੱਦ ਕਰੋ",
    "delete": "ਹਟਾਓ",
    "edit": "ਸੰਪਾਦਿਤ ਕਰੋ",
    "add": "ਜੋੜੋ",
    "close": "ਬੰਦ ਕਰੋ",
    "search": "ਖੋਜ",
    "filter": "ਫਿਲਟਰ",
    "share": "ਸਾਂਝਾ ਕਰੋ",
    "report": "ਰਿਪੋਰਟ ਕਰੋ",
    "more": "ਹੋਰ",
    "back": "ਪਿਛਲਾ",
    "next": "ਅਗਲਾ",
    "done": "ਤਿਆਰ",
    
    # Navigation
    "home": "ਮੁੱਖ ਪੰਨਾ",
    "profile": "ਪ੍ਰੋਫਾਇਲ",
    "favorites": "ਪਸੰਦੀਦਾ",
    "saved": "ਸੰਭਾਲਿਆ",
    "notifications": "ਸੂਚਨਾ",
    "settings": "ਸੈਟਿੰਗਜ਼",
    
    # Business details
    "foodBusinessDetails": "ਕਾਰੋਬਾਰ ਦੇ ਵਿਸਥਾਰ",
    "aboutThisFoodExperience": "ਇਸ ਭੋਜਨ ਬਾਰੇ",
    "businessInfo": "ਕਾਰੋਬਾਰ ਦੀ ਜਾਣਕਾਰੀ",
    "address": "ਪਤਾ",
    "phone": "ਫ਼ੋਨ",
    "website": "ਵੈਬਸਾਇਟ",
    "openingHours": "ਖੁੱਲਣ ਦਾ ਸਮਾਂ",
    "openNow": "ਹੁਣ ਖੁਲਲਾ",
    "closed": "ਬੰਦ",
    "callBusiness": "ਕਾਲ ਕਰੋ",
    "visitWebsite": "ਵੈਬਸਾਇਟ ਦਿਖਾਓ",
    "getDirections": "ਦਿਸ਼ਾ-ਨਿਰਦੇਸ਼ ਦਿਖਾਓ",
    
    # Reviews & ratings
    "reviews": "ਸਮਾਲੋਚਨਾ",
    "rating": "ਰੇਟਿੰਗ",
    "buzz": "ਬਜ",
    "noReviews": "ਕੋਈ ਸਮਾਲੋਚਨਾ ਨਹੀਂ",
    "writeAReview": "ਸਮਾਲੋਚਨਾ ਲਿਖੋ",
    "reviewSubmitted": "ਸਮਾਲੋਚਨਾ ਜਮਾ ਹੋ ਗਈ",
    "deleteReview": "ਸਮਾਲੋਚਨਾ ਹਟਾਓ",
    "editReview": "ਸਮਾਲੋਚਨਾ ਸੰਪਾਦਿਤ ਕਰੋ",
    
    # Photos & media
    "photos": "ਫ਼ੋਟੋ",
    "noPhotos": "ਕੋਈ ਫ਼ੋਟੋ ਨਹੀਂ",
    "uploadPhoto": "ਫ਼ੋਟੋ ਅਪਲੋਡ ਕਰੋ",
    "viewPhoto": "ਫ਼ੋਟੋ ਦੇਖੋ",
    
    # Events
    "events": "ਅਨੁ਷ਠਾਨ",
    "noEvents": "ਕੋਈ ਅਨੁ਷ਠਾਨ ਨਹੀਂ",
    "eventDetails": "ਅਨੁ਷ਠਾਨ ਦੇ ਵਿਸਥਾਰ",
    "eventDate": "ਮਿਤੀ",
    "eventTime": "ਸਮਾਂ",
    "eventLocation": "ਸਥਾਨ",
    "eventDescription": "ਵਿਵਰਣ",
    "interestedInEvent": "ਅਨੁ਷ਠਾਨ ਵਿੱਚ ਦਿਲਚਸਪ",
    "notInterestedInEvent": "ਅਨੁ਷ਠਾਨ ਵਿੱਚ ਦਿਲਚਸਪ ਨਹੀਂ",
    
    # Errors & messages
    "error": "ਗਲਤੀ",
    "success": "ਸਫਲ",
    "loading": "ਲੋਡ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ...",
    "noResults": "ਕੋਈ ਨਤੀਜਾ ਨਹੀਂ ਮਿਲਿਆ",
    "errorLoading": "ਲੋਡ ਕਰਦੇ ਸਮੇਂ ਗਲਤੀ",
    "tryAgain": "ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ",
    
    # Profile & account
    "profileInfo": "ਪ੍ਰੋਫਾਇਲ ਜਾਣਕਾਰੀ",
    "editProfile": "ਪ੍ਰੋਫਾਇਲ ਸੰਪਾਦਿਤ ਕਰੋ",
    "deleteAccount": "ਖਾਤਾ ਹਟਾਓ",
    "logout": "ਸਾਈਨ ਆਊਟ",
    "preferences": "ਤਰਜੀਹਾਂ",
    "language": "ਭਾਸ਼ਾ",
    "theme": "ਥੀਮ",
}

# Load existing Punjabi file
with open('lib/l10n/app_pa.arb', 'r', encoding='utf-8') as f:
    pa_data = json.load(f)

# Update with translations
count = 0
for key, trans in punjabi_translations.items():
    if key in pa_data:
        # Only update if currently has English placeholder
        old_value = pa_data[key]
        if old_value != trans:
            pa_data[key] = trans
            count += 1

print(f"Updated {count} Punjabi translations")

# Save updated file
with open('lib/l10n/app_pa.arb', 'w', encoding='utf-8') as f:
    json.dump(pa_data, f, ensure_ascii=False, indent=2)

print("Punjabi translations expanded!")
