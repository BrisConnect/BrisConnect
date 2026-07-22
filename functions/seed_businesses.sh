#!/bin/bash

# Firebase project info
PROJECT_ID="brisconnect-68b78"
API_KEY="AIzaSyBosCAp3VFaZZ01YIEyhSZLSMn8L3--NIs"  # From firebase_options.dart web config

# Base URL for Firestore REST API
BASE_URL="https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents"

# Sample businesses data
BUSINESSES=(
  '{
    "name": {"stringValue": "The Grill House"},
    "description": {"stringValue": "Premium steakhouse with locally sourced beef and an extensive wine collection"},
    "address": {"stringValue": "47 Eagle Street, Brisbane City QLD 4000"},
    "phone": {"stringValue": "+61 7 3229 8899"},
    "website": {"stringValue": "www.grillhouse.com.au"},
    "cuisineTypes": {"arrayValue": {"values": [{"stringValue": "Steakhouse"}, {"stringValue": "Australian"}, {"stringValue": "Fine Dining"}]}},
    "imageUrl": {"stringValue": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500"},
    "latitude": {"doubleValue": -27.4772},
    "longitude": {"doubleValue": 153.0290},
    "averageRating": {"doubleValue": 4.7},
    "reviewCount": {"integerValue": "156"}
  }'
  '{
    "name": {"stringValue": "Noodle Palace"},
    "description": {"stringValue": "Authentic Asian noodles and dim sum, family owned since 1995"},
    "address": {"stringValue": "123 Fortitude Valley Drive, Fortitude Valley QLD 4006"},
    "phone": {"stringValue": "+61 7 3252 4455"},
    "website": {"stringValue": "www.noodlepalace.com.au"},
    "cuisineTypes": {"arrayValue": {"values": [{"stringValue": "Asian"}, {"stringValue": "Chinese"}, {"stringValue": "Vietnamese"}]}},
    "imageUrl": {"stringValue": "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=500&h=500"},
    "latitude": {"doubleValue": -27.4566},
    "longitude": {"doubleValue": 153.0343},
    "averageRating": {"doubleValue": 4.5},
    "reviewCount": {"integerValue": "234"}
  }'
  '{
    "name": {"stringValue": "The Olive Tree"},
    "description": {"stringValue": "Mediterranean cuisine featuring fresh seafood and wood-fired pizza"},
    "address": {"stringValue": "89 Caxton Street, Paddington QLD 4064"},
    "phone": {"stringValue": "+61 7 3367 2555"},
    "website": {"stringValue": "www.olivetree.com.au"},
    "cuisineTypes": {"arrayValue": {"values": [{"stringValue": "Mediterranean"}, {"stringValue": "Italian"}, {"stringValue": "Seafood"}]}},
    "imageUrl": {"stringValue": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=500&h=500"},
    "latitude": {"doubleValue": -27.4742},
    "longitude": {"doubleValue": 153.0062},
    "averageRating": {"doubleValue": 4.6},
    "reviewCount": {"integerValue": "189"}
  }'
  '{
    "name": {"stringValue": "Spice Route"},
    "description": {"stringValue": "Indian restaurant with traditional recipes and modern fusion dishes"},
    "address": {"stringValue": "156 Wickham Street, Fortitude Valley QLD 4006"},
    "phone": {"stringValue": "+61 7 3854 1688"},
    "website": {"stringValue": "www.spiceroute.com.au"},
    "cuisineTypes": {"arrayValue": {"values": [{"stringValue": "Indian"}, {"stringValue": "Curry"}, {"stringValue": "Asian Fusion"}]}},
    "imageUrl": {"stringValue": "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500&h=500"},
    "latitude": {"doubleValue": -27.4582},
    "longitude": {"doubleValue": 153.0378},
    "averageRating": {"doubleValue": 4.4},
    "reviewCount": {"integerValue": "142"}
  }'
  '{
    "name": {"stringValue": "Urban Cafe"},
    "description": {"stringValue": "Trendy brunch spot with specialty coffee and contemporary Australian food"},
    "address": {"stringValue": "234 Queen Street, Brisbane City QLD 4000"},
    "phone": {"stringValue": "+61 7 3210 5567"},
    "website": {"stringValue": "www.urbancafe.com.au"},
    "cuisineTypes": {"arrayValue": {"values": [{"stringValue": "Cafe"}, {"stringValue": "Australian"}, {"stringValue": "Brunch"}]}},
    "imageUrl": {"stringValue": "https://images.unsplash.com/photo-1567521464027-f127ff144326?w=500&h=500"},
    "latitude": {"doubleValue": -27.4741},
    "longitude": {"doubleValue": 153.0289},
    "averageRating": {"doubleValue": 4.3},
    "reviewCount": {"integerValue": "267"}
  }'
  '{
    "name": {"stringValue": "Burger Barn"},
    "description": {"stringValue": "Craft burgers with hand-cut fries and fresh local ingredients"},
    "address": {"stringValue": "345 Boundary Street, South Brisbane QLD 4101"},
    "phone": {"stringValue": "+61 7 3844 9876"},
    "website": {"stringValue": "www.burgerbarn.com.au"},
    "cuisineTypes": {"arrayValue": {"values": [{"stringValue": "Burgers"}, {"stringValue": "Fast Casual"}, {"stringValue": "American"}]}},
    "imageUrl": {"stringValue": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500"},
    "latitude": {"doubleValue": -27.4826},
    "longitude": {"doubleValue": 153.0277},
    "averageRating": {"doubleValue": 4.2},
    "reviewCount": {"integerValue": "198"}
  }'
)

echo "Seeding food businesses to Firestore..."
for i in "${!BUSINESSES[@]}"; do
  BUSINESS="${BUSINESSES[$i]}"
  RESPONSE=$(curl -s -X POST \
    "${BASE_URL}/businesses?key=${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"fields\": ${BUSINESS}}")
  
  echo "Added business $((i+1))/6: $RESPONSE"
done

echo "✅ Seeding complete!"
