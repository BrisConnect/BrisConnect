/**
 * Backfill sample menus for existing food_businesses documents.
 *
 * Usage:
 *   cd functions
 *   export GOOGLE_APPLICATION_CREDENTIALS="../service-account-key.json"
 *   node backfill_food_business_menus.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, '../service-account-key.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Service account key not found at:', serviceAccountPath);
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

const menuTemplates = {
  Restaurant: [
    { category: 'Mains', name: 'Grilled Salmon', price: '$28', description: 'Atlantic salmon with seasonal vegetables and lemon butter sauce.', tags: ['Gluten Free'] },
    { category: 'Mains', name: 'Beef Burger', price: '$24', description: 'Wagyu beef patty, brioche bun, cheddar, pickles, and house sauce.', tags: [] },
    { category: 'Starters', name: 'Garlic Bread', price: '$9', description: 'Wood-fired sourdough with roasted garlic butter.', tags: ['Vegetarian'] },
    { category: 'Desserts', name: 'Chocolate Fondant', price: '$14', description: 'Warm chocolate cake with vanilla bean ice cream.', tags: ['Vegetarian'] },
  ],
  Cafe: [
    { category: 'Coffee', name: 'Flat White', price: '$5', description: 'Double ristretto with steamed milk.', tags: [] },
    { category: 'Brunch', name: 'Smashed Avo', price: '$19', description: 'Sourdough, smashed avocado, feta, poached eggs, and dukkah.', tags: ['Vegetarian'] },
    { category: 'Brunch', name: 'Eggs Benedict', price: '$21', description: 'Poached eggs, hollandaise, ham, and English muffin.', tags: [] },
    { category: 'Pastries', name: 'Almond Croissant', price: '$7', description: 'Buttery croissant filled with almond cream.', tags: ['Vegetarian'] },
  ],
  Bar: [
    { category: 'Small Plates', name: 'Truffle Fries', price: '$12', description: 'Crispy fries with parmesan and truffle oil.', tags: ['Vegetarian', 'Gluten Free'] },
    { category: 'Small Plates', name: 'Chicken Wings', price: '$16', description: 'Sticky buffalo wings with blue cheese dip.', tags: [] },
    { category: 'Drinks', name: 'House Beer', price: '$10', description: 'Local craft lager on tap.', tags: [] },
    { category: 'Drinks', name: 'Classic Cocktail', price: '$18', description: 'Choose from mojito, margarita, or old fashioned.', tags: [] },
  ],
  Bakery: [
    { category: 'Baked Goods', name: 'Sourdough Loaf', price: '$8', description: 'Naturally fermented country sourdough.', tags: ['Vegan'] },
    { category: 'Baked Goods', name: 'Meat Pie', price: '$7', description: 'Classic beef and gravy pie in flaky pastry.', tags: [] },
    { category: 'Sweet', name: 'Vanilla Slice', price: '$6', description: 'Custard slice with passionfruit icing.', tags: ['Vegetarian'] },
  ],
  Pizza: [
    { category: 'Pizza', name: 'Margherita', price: '$18', description: 'San Marzano tomato, mozzarella, and fresh basil.', tags: ['Vegetarian'] },
    { category: 'Pizza', name: 'Pepperoni', price: '$22', description: 'Tomato, mozzarella, and spicy pepperoni.', tags: [] },
    { category: 'Pizza', name: 'Prosciutto & Rocket', price: '$24', description: 'Tomato, mozzarella, prosciutto, rocket, and parmesan.', tags: [] },
    { category: 'Sides', name: 'Garlic Pizza Bread', price: '$10', description: 'Mozzarella, garlic, and herbs.', tags: ['Vegetarian'] },
  ],
  Japanese: [
    { category: 'Sushi', name: 'Salmon Nigiri (5pc)', price: '$14', description: 'Fresh Tasmanian salmon on seasoned rice.', tags: ['Gluten Free'] },
    { category: 'Rolls', name: 'Dragon Roll', price: '$18', description: 'Prawn tempura, avocado, and unagi sauce.', tags: [] },
    { category: 'Mains', name: 'Teriyaki Chicken Don', price: '$20', description: 'Grilled chicken, teriyaki sauce, and rice.', tags: [] },
    { category: 'Drinks', name: 'Green Tea', price: '$4', description: 'Hot Japanese sencha.', tags: ['Vegan'] },
  ],
  Asian: [
    { category: 'Noodles', name: 'Pad Thai', price: '$17', description: 'Rice noodles, prawns, tofu, peanuts, and tamarind.', tags: [] },
    { category: 'Curry', name: 'Green Curry', price: '$19', description: 'Thai green curry with chicken, bamboo shoots, and basil.', tags: ['Gluten Free'] },
    { category: 'Dumplings', name: 'Pork Gyoza (6pc)', price: '$12', description: 'Pan-fried pork and vegetable dumplings.', tags: [] },
  ],
  Thai: [
    { category: 'Curry', name: 'Massaman Beef Curry', price: '$22', description: 'Slow-cooked beef in massaman curry with potato and peanuts.', tags: ['Gluten Free'] },
    { category: 'Noodles', name: 'Drunken Noodles', price: '$18', description: 'Wide rice noodles with basil, chilli, and vegetables.', tags: [] },
    { category: 'Salad', name: 'Larb Gai', price: '$16', description: 'Spicy minced chicken salad with lime and mint.', tags: ['Gluten Free'] },
  ],
  Indian: [
    { category: 'Curry', name: 'Butter Chicken', price: '$20', description: 'Tandoori chicken in rich tomato and butter gravy.', tags: ['Gluten Free'] },
    { category: 'Curry', name: 'Palak Paneer', price: '$18', description: 'Cottage cheese in spiced spinach.', tags: ['Vegetarian', 'Gluten Free'] },
    { category: 'Bread', name: 'Garlic Naan', price: '$5', description: 'Leavened bread with garlic and coriander.', tags: ['Vegetarian'] },
  ],
  Mexican: [
    { category: 'Tacos', name: 'Fish Tacos (3pc)', price: '$16', description: 'Battered fish, cabbage slaw, and chipotle mayo.', tags: [] },
    { category: 'Mains', name: 'Beef Burrito', price: '$18', description: 'Slow-cooked beef, rice, beans, and cheese.', tags: [] },
    { category: 'Sides', name: 'Guacamole & Chips', price: '$12', description: 'Fresh guacamole with corn chips.', tags: ['Vegan', 'Gluten Free'] },
  ],
  Italian: [
    { category: 'Pasta', name: 'Spaghetti Carbonara', price: '$22', description: 'Pancetta, egg, parmesan, and black pepper.', tags: [] },
    { category: 'Pasta', name: 'Penne Arrabbiata', price: '$19', description: 'Spicy tomato sauce with garlic and chilli.', tags: ['Vegetarian'] },
    { category: 'Mains', name: 'Chicken Parmigiana', price: '$26', description: 'Crumbed chicken with napoli, ham, and mozzarella.', tags: [] },
  ],
  Chinese: [
    { category: 'Dumplings', name: 'Xiao Long Bao (6pc)', price: '$14', description: 'Shanghai soup dumplings with pork.', tags: [] },
    { category: 'Noodles', name: 'Dan Dan Noodles', price: '$17', description: 'Spicy Sichuan noodles with minced pork.', tags: [] },
    { category: 'Mains', name: 'Kung Pao Chicken', price: '$21', description: 'Stir-fried chicken with peanuts and dried chilli.', tags: [] },
  ],
  Vietnamese: [
    { category: 'Pho', name: 'Beef Pho', price: '$16', description: 'Rice noodle soup with slow-cooked beef and herbs.', tags: ['Gluten Free'] },
    { category: 'Banh Mi', name: 'Pork Banh Mi', price: '$12', description: 'Crispy baguette with pate, pork, and pickled veg.', tags: [] },
    { category: 'Rolls', name: 'Rice Paper Rolls (4pc)', price: '$10', description: 'Prawn and pork with hoisin peanut sauce.', tags: ['Gluten Free'] },
  ],
  Korean: [
    { category: 'BBQ', name: 'Bulgogi Beef', price: '$26', description: 'Marinated beef grilled at the table.', tags: ['Gluten Free'] },
    { category: 'Stews', name: 'Kimchi Jjigae', price: '$18', description: 'Kimchi stew with tofu and pork.', tags: [] },
    { category: 'Street Food', name: 'Korean Fried Chicken', price: '$20', description: 'Crispy fried chicken with soy garlic glaze.', tags: [] },
  ],
  Seafood: [
    { category: 'Seafood', name: 'Fish & Chips', price: '$22', description: 'Beer-battered fish with chips and tartare.', tags: [] },
    { category: 'Seafood', name: 'Grilled Prawns', price: '$28', description: 'King prawns with garlic butter and lemon.', tags: ['Gluten Free'] },
    { category: 'Mains', name: 'Seafood Platter', price: '$45', description: 'Oysters, prawns, calamari, and fish for two.', tags: [] },
  ],
  Steakhouse: [
    { category: 'Steaks', name: 'Ribeye (300g)', price: '$42', description: 'Grain-fed ribeye with red wine jus.', tags: ['Gluten Free'] },
    { category: 'Steaks', name: 'Sirloin (250g)', price: '$36', description: 'Grass-fed sirloin with herb butter.', tags: ['Gluten Free'] },
    { category: 'Sides', name: 'Truffle Mac & Cheese', price: '$14', description: 'Creamy macaroni with truffle oil and parmesan.', tags: ['Vegetarian'] },
  ],
  Brunch: [
    { category: 'Brunch', name: 'Pancakes', price: '$18', description: 'Fluffy pancakes with maple syrup and berries.', tags: ['Vegetarian'] },
    { category: 'Brunch', name: 'Big Breakfast', price: '$24', description: 'Eggs, bacon, sausages, mushrooms, avocado, and toast.', tags: [] },
    { category: 'Coffee', name: 'Long Black', price: '$4.50', description: 'Double espresso with hot water.', tags: [] },
  ],
  Coffee: [
    { category: 'Coffee', name: 'Espresso', price: '$3.50', description: 'Single origin daily espresso.', tags: [] },
    { category: 'Coffee', name: 'Cold Brew', price: '$6', description: 'Slow-steeped cold brew over ice.', tags: [] },
    { category: 'Pastry', name: 'Banana Bread', price: '$8', description: 'Toasted with butter and honey.', tags: ['Vegetarian'] },
  ],
  Mediterranean: [
    { category: 'Shared', name: 'Hummus & Pita', price: '$12', description: 'Creamy hummus with warm pita bread.', tags: ['Vegetarian'] },
    { category: 'Mains', name: 'Lamb Souvlaki', price: '$23', description: 'Grilled lamb skewers with tzatziki and salad.', tags: ['Gluten Free'] },
    { category: 'Salads', name: 'Greek Salad', price: '$16', description: 'Tomato, cucumber, olives, feta, and oregano.', tags: ['Vegetarian', 'Gluten Free'] },
  ],
};

const fallbackMenu = menuTemplates.Restaurant;

function buildMenu(cuisineTypes) {
  const cuisines = Array.isArray(cuisineTypes) ? cuisineTypes : [];
  const matched = cuisines
    .map((c) => String(c).trim())
    .find((c) => menuTemplates[c] != null);
  const template = menuTemplates[matched] || fallbackMenu;
  // Return a shallow copy so each business gets its own list.
  return template.map((item) => ({ ...item }));
}

async function backfillMenus() {
  console.log('🍽️  Backfilling menus for food_businesses...');
  const snapshot = await db.collection('food_businesses').get();
  let updated = 0;
  let skipped = 0;
  let errors = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (Array.isArray(data.menu) && data.menu.length > 0) {
      skipped += 1;
      continue;
    }

    const menu = buildMenu(data.cuisineTypes);
    try {
      await doc.ref.update({ menu });
      updated += 1;
      console.log(`✅ ${doc.id}: added ${menu.length} menu items`);
    } catch (error) {
      errors += 1;
      console.error(`❌ ${doc.id}: ${error.message}`);
    }
  }

  console.log(`\nDone. Updated: ${updated}, Skipped: ${skipped}, Errors: ${errors}`);
}

backfillMenus()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Backfill failed:', error);
    process.exit(1);
  });
