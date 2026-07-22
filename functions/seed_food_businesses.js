const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials
admin.initializeApp({
  projectId: 'brisconnect-68b78',
});

const db = admin.firestore();

const sampleBusinesses = [
  // Fine Dining & Steakhouses
  {
    name: 'The Grill House',
    description: 'Premium steakhouse with locally sourced beef and an extensive wine collection',
    address: '47 Eagle Street, Brisbane City QLD 4000',
    phone: '+61 7 3229 8899',
    website: 'www.grillhouse.com.au',
    cuisineTypes: ['Steakhouse', 'Australian', 'Fine Dining'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4772,
    longitude: 153.0290,
    averageRating: 4.7,
    reviewCount: 156,
    priceRange: '$$$',
    operatingHours: {
      monday: { open: '11:30', close: '22:00' },
      tuesday: { open: '11:30', close: '22:00' },
      wednesday: { open: '11:30', close: '22:00' },
      thursday: { open: '11:30', close: '23:00' },
      friday: { open: '11:30', close: '23:00' },
      saturday: { open: '17:00', close: '23:00' },
      sunday: { open: '17:00', close: '22:00' },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    name: 'Scene Restaurant',
    description: 'Award-winning fine dining with modern Australian cuisine and city views',
    address: '1 Eagle Street, Brisbane City QLD 4000',
    phone: '+61 7 3220 0222',
    website: 'www.scene.com.au',
    cuisineTypes: ['Modern Australian', 'Fine Dining', 'Seafood'],
    imageUrl: 'https://images.unsplash.com/photo-1559027615-cd4628902d4a?w=500&h=500',
    latitude: -27.4768,
    longitude: 153.0298,
    averageRating: 4.8,
    reviewCount: 342,
    priceRange: '$$$',
    operatingHours: {
      monday: { open: '12:00', close: '14:30' },
      tuesday: { open: '12:00', close: '14:30' },
      wednesday: { open: '12:00', close: '14:30' },
      thursday: { open: '12:00', close: '14:30' },
      friday: { open: '12:00', close: '22:00' },
      saturday: { open: '17:30', close: '22:00' },
      sunday: { closed: true },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  // Asian Cuisine
  {
    name: 'Noodle Palace',
    description: 'Authentic Asian noodles and dim sum, family owned since 1995',
    address: '123 Fortitude Valley Drive, Fortitude Valley QLD 4006',
    phone: '+61 7 3252 4455',
    website: 'www.noodlepalace.com.au',
    cuisineTypes: ['Asian', 'Chinese', 'Vietnamese'],
    imageUrl: 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=500&h=500',
    latitude: -27.4566,
    longitude: 153.0343,
    averageRating: 4.5,
    reviewCount: 234,
    priceRange: '$',
    operatingHours: {
      monday: { open: '10:00', close: '22:30' },
      tuesday: { open: '10:00', close: '22:30' },
      wednesday: { open: '10:00', close: '22:30' },
      thursday: { open: '10:00', close: '23:00' },
      friday: { open: '10:00', close: '23:30' },
      saturday: { open: '11:00', close: '23:30' },
      sunday: { open: '11:00', close: '22:00' },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    name: 'The Olive Tree',
    description: 'Mediterranean cuisine featuring fresh seafood and wood-fired pizza',
    address: '89 Caxton Street, Paddington QLD 4064',
    phone: '+61 7 3367 2555',
    website: 'www.olivetree.com.au',
    cuisineTypes: ['Mediterranean', 'Italian', 'Seafood'],
    imageUrl: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=500&h=500',
    latitude: -27.4742,
    longitude: 153.0062,
    averageRating: 4.6,
    reviewCount: 189,
    operatingHours: {
      monday: { open: '12:00', close: '22:00' },
      tuesday: { open: '12:00', close: '22:00' },
      wednesday: { open: '12:00', close: '22:00' },
      thursday: { open: '12:00', close: '23:00' },
      friday: { open: '12:00', close: '23:00' },
      saturday: { open: '12:00', close: '23:00' },
      sunday: { open: '12:00', close: '21:30' },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    name: 'Spice Route',
    description: 'Indian restaurant with traditional recipes and modern fusion dishes',
    address: '156 Wickham Street, Fortitude Valley QLD 4006',
    phone: '+61 7 3854 1688',
    website: 'www.spiceroute.com.au',
    cuisineTypes: ['Indian', 'Curry', 'Asian Fusion'],
    imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500&h=500',
    latitude: -27.4582,
    longitude: 153.0378,
    averageRating: 4.4,
    reviewCount: 142,
    operatingHours: {
      monday: { open: '11:30', close: '22:30' },
      tuesday: { open: '11:30', close: '22:30' },
      wednesday: { open: '11:30', close: '22:30' },
      thursday: { open: '11:30', close: '23:00' },
      friday: { open: '11:30', close: '23:30' },
      saturday: { open: '17:00', close: '23:30' },
      sunday: { open: '17:00', close: '22:30' },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    name: 'Urban Cafe',
    description: 'Trendy brunch spot with specialty coffee and contemporary Australian food',
    address: '234 Queen Street, Brisbane City QLD 4000',
    phone: '+61 7 3210 5567',
    website: 'www.urbancafe.com.au',
    cuisineTypes: ['Cafe', 'Australian', 'Brunch'],
    imageUrl: 'https://images.unsplash.com/photo-1567521464027-f127ff144326?w=500&h=500',
    latitude: -27.4741,
    longitude: 153.0289,
    averageRating: 4.3,
    reviewCount: 267,
    operatingHours: {
      monday: { open: '07:00', close: '17:00' },
      tuesday: { open: '07:00', close: '17:00' },
      wednesday: { open: '07:00', close: '17:00' },
      thursday: { open: '07:00', close: '17:00' },
      friday: { open: '07:00', close: '18:00' },
      saturday: { open: '08:00', close: '16:00' },
      sunday: { open: '08:00', close: '16:00' },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    name: 'Burger Barn',
    description: 'Craft burgers with hand-cut fries and fresh local ingredients',
    address: '345 Boundary Street, South Brisbane QLD 4101',
    phone: '+61 7 3844 9876',
    website: 'www.burgerbarn.com.au',
    cuisineTypes: ['Burgers', 'Fast Casual', 'American'],
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&h=500',
    latitude: -27.4826,
    longitude: 153.0277,
    averageRating: 4.2,
    reviewCount: 198,
    operatingHours: {
      monday: { open: '11:00', close: '21:00' },
      tuesday: { open: '11:00', close: '21:00' },
      wednesday: { open: '11:00', close: '21:00' },
      thursday: { open: '11:00', close: '22:00' },
      friday: { open: '11:00', close: '22:00' },
      saturday: { open: '12:00', close: '22:00' },
      sunday: { open: '12:00', close: '21:00' },
    },
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
];

async function seedBusinesses() {
  try {
    console.log('Starting to seed food businesses...');
    const batch = db.batch();

    for (const business of sampleBusinesses) {
      const docRef = db.collection('businesses').doc();
      batch.set(docRef, business);
      console.log(`Prepared: ${business.name}`);
    }

    await batch.commit();
    console.log(`✅ Successfully seeded ${sampleBusinesses.length} food businesses!`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding businesses:', error);
    process.exit(1);
  }
}

seedBusinesses();
