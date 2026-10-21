import "dotenv/config";
import mongoose from "mongoose";
import { Item } from "./models/item.models.js";
import { User } from "./models/user.models.js";
import { admin } from "./utils/firebase_app.js";

export const sampleFoodItems = [
  // 1. Burgers
  {
    itemName: "Veggie Crunch Burger",
    itemPrice: 89,
    category: "Burgers",
    description: "Crispy mixed vegetable patty with lettuce, tomatoes, and creamy mayo",
    isAvailable: true,
  },
  {
    itemName: "Classic Cheese Burger",
    itemPrice: 119,
    category: "Burgers",
    description: "Spiced potato and paneer patty layered with melted cheese slice",
    isAvailable: true,
  },
  {
    itemName: "Spicy Paneer Burger",
    itemPrice: 139,
    category: "Burgers",
    description: "Grilled cottage cheese marinated in peri-peri spices with mint mayo",
    isAvailable: true,
  },

  // 2. Pizza
  {
    itemName: "Margherita Pizza",
    itemPrice: 159,
    category: "Pizza",
    description: "Classic single cheese pizza with fresh basil and herb tomato sauce",
    isAvailable: true,
  },
  {
    itemName: "Farmhouse Veggie Pizza",
    itemPrice: 189,
    category: "Pizza",
    description: "Loaded with capsicum, onion, tomato, sweet corn, and mozzarella",
    isAvailable: true,
  },
  {
    itemName: "Paneer Tikka Pizza",
    itemPrice: 219,
    category: "Pizza",
    description: "Tandoori spiced paneer cubes, capsicum, red paprika, and cheese",
    isAvailable: true,
  },

  // 3. Sandwiches
  {
    itemName: "Veg Grilled Sandwich",
    itemPrice: 79,
    category: "Sandwiches",
    description: "Toasted multigrain bread with fresh cucumber, tomato, and mint chutney",
    isAvailable: true,
  },
  {
    itemName: "Cheese Corn Grilled Sandwich",
    itemPrice: 99,
    category: "Sandwiches",
    description: "Loaded with sweet American corn and gooey melted cheese",
    isAvailable: true,
  },
  {
    itemName: "Paneer Tikka Sandwich",
    itemPrice: 119,
    category: "Sandwiches",
    description: "Spicy grilled paneer slices with bell peppers and green chutney",
    isAvailable: true,
  },

  // 4. Snacks
  {
    itemName: "Crispy French Fries",
    itemPrice: 69,
    category: "Snacks",
    description: "Golden salted potato fries served with tomato ketchup",
    isAvailable: true,
  },
  {
    itemName: "Peri Peri Fries",
    itemPrice: 79,
    category: "Snacks",
    description: "Crisp fries tossed in zesty peri-peri seasoning",
    isAvailable: true,
  },
  {
    itemName: "Punjabi Samosa (2 pcs)",
    itemPrice: 40,
    category: "Snacks",
    description: "Crispy flaky pastry stuffed with spiced potato and green peas",
    isAvailable: true,
  },
  {
    itemName: "Cheese Nachos",
    itemPrice: 89,
    category: "Snacks",
    description: "Corn tortilla chips topped with warm cheese sauce and jalapeños",
    isAvailable: true,
  },

  // 5. Beverages
  {
    itemName: "Cold Coffee",
    itemPrice: 79,
    category: "Beverages",
    description: "Thick and frothy iced coffee blended with milk and chocolate drizzle",
    isAvailable: true,
  },
  {
    itemName: "Lemon Iced Tea",
    itemPrice: 59,
    category: "Beverages",
    description: "Refreshing chilled black tea infused with real lemon and mint",
    isAvailable: true,
  },
  {
    itemName: "Masala Chai",
    itemPrice: 25,
    category: "Beverages",
    description: "Traditional Indian spiced tea brewed with ginger and cardamom",
    isAvailable: true,
  },
  {
    itemName: "Fresh Lime Soda",
    itemPrice: 49,
    category: "Beverages",
    description: "Sweet and salted chilled sparkling lime refreshment",
    isAvailable: true,
  },

  // 6. Desserts
  {
    itemName: "Chocolate Brownie",
    itemPrice: 89,
    category: "Desserts",
    description: "Warm, fudgy dark chocolate brownie topped with chocolate syrup",
    isAvailable: true,
  },
  {
    itemName: "Gulab Jamun (2 pcs)",
    itemPrice: 50,
    category: "Desserts",
    description: "Soft melt-in-mouth milk dumplings soaked in cardamom sugar syrup",
    isAvailable: true,
  },
  {
    itemName: "Vanilla Choco-Sundae",
    itemPrice: 69,
    category: "Desserts",
    description: "Creamy vanilla ice cream topped with hot chocolate fudge and nuts",
    isAvailable: true,
  },
];

export async function seedDatabase() {
  if (!process.env.MONGO_URI) {
    console.error("Error: MONGO_URI is not set in environment or .env file.");
    process.exit(1);
  }

  try {
    console.log("Connecting to MongoDB Atlas...");
    await mongoose.connect(process.env.MONGO_URI);
    console.log("Connected successfully to MongoDB.");

    let inserted = 0;
    let updated = 0;

    for (const item of sampleFoodItems) {
      const existing = await Item.findOne({ itemName: item.itemName });
      if (existing) {
        await Item.updateOne({ itemName: item.itemName }, { $set: item });
        updated++;
      } else {
        await Item.create(item);
        inserted++;
      }
    }

    console.log(`Seed Complete: ${inserted} items inserted, ${updated} items updated.`);
    const totalCount = await Item.countDocuments();
    console.log(`Total menu items in database: ${totalCount}`);

    // Check / provision admin account if ADMIN_PASSWORD is provided
    const adminEmail = "admin123@ad.in";
    try {
      const existingAdmin = await admin.auth().getUserByEmail(adminEmail);
      console.log(`Admin account [${adminEmail}] already exists in Firebase Auth (UID: ${existingAdmin.uid}).`);

      // Ensure admin document exists in MongoDB
      const adminInDb = await User.findOne({ email: adminEmail });
      if (!adminInDb) {
        await User.create({
          uid: existingAdmin.uid,
          fullName: "Admin",
          email: adminEmail,
          password: "protected",
          phoneNumber: "9999999999",
        });
        console.log(`Created MongoDB record for admin [${adminEmail}].`);
      }
    } catch (err) {
      if (err.code === "auth/user-not-found" || err.message?.includes("no user record")) {
        const adminPass = process.env.ADMIN_PASSWORD;
        if (adminPass) {
          const newAdmin = await admin.auth().createUser({
            email: adminEmail,
            password: adminPass,
            displayName: "Admin",
          });
          console.log(`Provisioned new admin account [${adminEmail}] in Firebase Auth.`);

          await User.create({
            uid: newAdmin.uid,
            fullName: "Admin",
            email: adminEmail,
            password: "protected",
            phoneNumber: "9999999999",
          });
          console.log(`Created MongoDB record for admin [${adminEmail}].`);
        } else {
          console.log(
            `Admin account [${adminEmail}] not yet created in Firebase Auth. ` +
            `To provision it, set ADMIN_PASSWORD in environment and run seed again, ` +
            `or add user [${adminEmail}] in Firebase Console.`
          );
        }
      } else {
        console.warn(`Admin check warning: ${err.message}`);
      }
    }

    await mongoose.disconnect();
    console.log("Disconnected from MongoDB.");
  } catch (error) {
    console.error("Seeding failed:", error);
    process.exit(1);
  }
}

seedDatabase();

