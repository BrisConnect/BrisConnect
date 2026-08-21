#!/usr/bin/env python3
import json

# Manually curated Punjabi translations for key strings
translations = {
    "foodBusinessDetails": "ਕਾਰੋਬਾਰ ਦੇ ਵਿਸਥਾਰ",
    "aboutThisFoodExperience": "ਇਸ ਭੋਜਨ ਬਾਰੇ",
    "openNow": "ਹੁਣ ਖੁਲਲਾ",
    "closed": "ਬੰਦ",
    "openingHours": "ਖੁੱਲਣ ਦਾ ਸਮਾਂ",
    "address": "ਪਤਾ",
    "phone": "ਫ਼ੋਨ",
    "website": "ਵੈਬਸਾਇਟ",
    "rating": "ਰੇਟਿੰਗ",
    "reviews": "ਸਮਾਲੋਚਨਾ",
    "noReviews": "ਕੋਈ ਸਮਾਲੋਚਨਾ ਨਹੀਂ",
    "writeAReview": "ਸਮਾਲੋਚਨਾ ਲਿਖੋ",
    "reviewSubmitted": "ਸਮਾਲੋਚਨਾ ਜਮਾ ਹੋ ਗਈ",
    "deleteAccount": "ਖਾਤਾ ਹਟਾਓ",
    "confirmDelete": "ਤੁਸੀਂ ਆਪਣਾ ਖਾਤਾ ਹਟਾਉਣ ਦੀ ਪੁਸ਼ਟੀ ਕਰਦੇ ਹੋ?",
    "share": "ਸਾਂਝਾ ਕਰੋ",
    "report": "ਰਿਪੋਰਟ ਕਰੋ",
    "photos": "ਫ਼ੋਟੋ",
    "noPhotos": "ਕੋਈ ਫ਼ੋਟੋ ਨਹੀਂ",
    "events": "ਅਨੁ਷ਠਾਨ",
    "noEvents": "ਕੋਈ ਅਨੁ਷ਠਾਨ ਨਹੀਂ",
}

# Load existing Punjabi file
with open('lib/l10n/app_pa.arb', 'r', encoding='utf-8') as f:
    pa_data = json.load(f)

# Update with translations
count = 0
for key, trans in translations.items():
    if key in pa_data:
        pa_data[key] = trans
        count += 1

print(f"Updated {count} Punjabi translations")

# Save updated file
with open('lib/l10n/app_pa.arb', 'w', encoding='utf-8') as f:
    json.dump(pa_data, f, ensure_ascii=False, indent=2)

print("Punjabi ARB file updated!")
