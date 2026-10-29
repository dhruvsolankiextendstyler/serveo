import assert from "assert";
import mongoose from "mongoose";
import { checkRestaurantAvailability } from "./utils/restaurant_availability.js";
import { addOrderController } from "./controllers/addOrder.controller.js";
import { getOrderController } from "./controllers/getOrder.controller.js";
import { verifyPaymentController } from "./controllers/verifyPayment.controller.js";
import { updateStatusController } from "./controllers/updateStatusController.js";
import {
  updateAdminRestaurantSettingsController,
  getPublicRestaurantInfoController,
  generateRestaurantQrController
} from "./controllers/restaurant.controller.js";
import { Restaurant } from "./models/restaurant.models.js";
import { Item } from "./models/item.models.js";
import { Order } from "./models/order.models.js";
import { User } from "./models/user.models.js";
import { Notification } from "./models/notification.models.js";

console.log("=== Running Serveo Phase 4 Restaurant Onboarding & Multi-Tenancy Tests ===");

// In-memory test restaurants
const restaurantAId = new mongoose.Types.ObjectId("65dfa0000000000000000001");
const restaurantBId = new mongoose.Types.ObjectId("65dfb0000000000000000002");

const mockRestaurants = [
  {
    _id: restaurantAId,
    name: "Serveo Bistro A",
    slug: "serveo-a",
    description: "Campus Block A Bistro",
    currency: "INR",
    currencySymbol: "₹",
    timezone: "Asia/Kolkata",
    operatingDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
    openingTime: "09:00",
    closingTime: "22:00",
    isOrderAcceptancePaused: false,
    pauseReason: "",
    defaultEstimatedPrepTime: 20,
    address: { street: "123 Main St", city: "Bengaluru", state: "KA", postalCode: "560001", country: "India" },
    contact: { phone: "+91 9876543210", email: "bistroA@serveo.test" },
    displayPreferences: { announcement: "Welcome to Bistro A", showPrepTime: true, showDietaryBadges: true },
    adminEmails: ["adminA@serveo.test", "admin123@ad.in"],
    adminUids: ["adminA_uid"],
    schedule: [
      { day: "Monday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      { day: "Tuesday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      { day: "Wednesday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      { day: "Thursday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      { day: "Friday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      { day: "Saturday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      { day: "Sunday", isOpen: false, openTime: "09:00", closeTime: "22:00" }, // Closed Sunday
    ],
    save: async function() { return this; },
    toObject: function() { return { ...this }; }
  },
  {
    _id: restaurantBId,
    name: "Serveo Night Diner B",
    slug: "serveo-b",
    description: "Late Night Dining",
    currency: "INR",
    currencySymbol: "₹",
    timezone: "Asia/Kolkata",
    operatingDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
    openingTime: "18:00",
    closingTime: "02:00", // Midnight crossing!
    isOrderAcceptancePaused: false,
    pauseReason: "",
    defaultEstimatedPrepTime: 25,
    address: { street: "456 Night St", city: "Bengaluru", state: "KA", postalCode: "560002", country: "India" },
    contact: { phone: "+91 9876543211", email: "dinerB@serveo.test" },
    displayPreferences: { announcement: "Late night orders", showPrepTime: true, showDietaryBadges: true },
    adminEmails: ["adminB@serveo.test"],
    adminUids: ["adminB_uid"],
    save: async function() { return this; },
    toObject: function() { return { ...this }; }
  }
];

Restaurant.findById = async (id) => mockRestaurants.find(r => r._id.toString() === id?.toString()) || null;
Restaurant.findOne = async (q) => {
  if (q.slug) return mockRestaurants.find(r => r.slug === q.slug) || null;
  if (q.adminEmails) return mockRestaurants.find(r => r.adminEmails.includes(q.adminEmails)) || null;
  if (q._id) return mockRestaurants.find(r => r._id.toString() === q._id.toString()) || null;
  return mockRestaurants[0] || null;
};

// In-memory catalog
const mockItems = [
  {
    _id: new mongoose.Types.ObjectId("65df00000000000000000010"),
    restaurantId: restaurantAId,
    itemName: "Cold Coffee",
    itemPrice: 80,
    category: "Beverages",
    isAvailable: true,
  },
  {
    _id: new mongoose.Types.ObjectId("65df00000000000000000011"),
    restaurantId: restaurantBId,
    itemName: "Cold Coffee", // Same name, different restaurant!
    itemPrice: 120, // Different price in Restaurant B!
    category: "Beverages",
    isAvailable: true,
  },
  {
    _id: new mongoose.Types.ObjectId("65df00000000000000000012"),
    restaurantId: restaurantAId,
    itemName: "Paneer Pizza",
    itemPrice: 220,
    category: "Pizza",
    isAvailable: true,
  }
];

Item.findById = async (id) => mockItems.find(i => i._id.toString() === id?.toString()) || null;
Item.findOne = async (q) => {
  return mockItems.find(i => {
    if (q._id && i._id.toString() !== q._id.toString()) return false;
    if (q.itemName && i.itemName !== q.itemName) return false;
    if (q.restaurantId && i.restaurantId.toString() !== q.restaurantId.toString()) return false;
    return true;
  }) || null;
};
Item.find = (q = {}) => {
  let list = mockItems;
  if (q.$or) {
    list = list.filter(i => q.$or.some(cond => cond.restaurantId && i.restaurantId.toString() === cond.restaurantId.toString()));
  }
  return {
    sort: () => ({
      lean: async () => list
    }),
    lean: async () => list
  };
};

const mockUser = {
  _id: new mongoose.Types.ObjectId("65df00000000000000000099"),
  uid: "cust_uid_44",
  email: "cust@serveo.test",
  fullName: "Rahul Verma",
  phoneNumber: "+919876543210"
};

User.findOne = async () => mockUser;

let savedOrders = [];
Order.prototype.save = async function() {
  const plain = this.toObject ? this.toObject() : { ...this };
  if (!plain._id) plain._id = new mongoose.Types.ObjectId();
  const idx = savedOrders.findIndex(o => o._id.toString() === plain._id.toString());
  if (idx >= 0) savedOrders[idx] = plain;
  else savedOrders.push(plain);
  return plain;
};
Order.findById = async (id) => savedOrders.find(o => o._id.toString() === id.toString()) || null;
Order.find = (q = {}) => {
  let list = [...savedOrders];
  if (q.$or) {
    const targetCond = q.$or.find(c => c.restaurantId);
    if (targetCond) {
      list = list.filter(o => o.restaurantId && o.restaurantId.toString() === targetCond.restaurantId.toString());
    }
  }
  return {
    populate: () => ({
      sort: () => list
    }),
    sort: () => list,
    lean: async () => list
  };
};
Order.findOneAndUpdate = (filter, update) => {
  const id = filter._id?.toString() || filter._id;
  const existing = savedOrders.find(o => o._id.toString() === id);
  if (!existing) {
    const p = Promise.resolve(null);
    p.populate = () => p;
    return p;
  }
  const updated = { ...existing, ...(update.$set || {}) };
  const idx = savedOrders.findIndex(o => o._id.toString() === id);
  savedOrders[idx] = updated;
  const p = Promise.resolve(updated);
  p.populate = () => p;
  return p;
};

Notification.create = async (doc) => ({ _id: new mongoose.Types.ObjectId(), ...doc });

// --- TEST 1: Operating Hours & Availability Engine ---
function testOperatingHoursAndAvailability() {
  console.log("\n[1] Testing Operating Hours & Availability Engine...");

  const restaurantA = mockRestaurants[0];

  // 1.1 Open during normal business hours on a Monday (14:30 IST)
  const mondayMidday = new Date("2026-10-26T09:00:00Z"); // 14:30 IST
  const mondayRes = checkRestaurantAvailability(restaurantA, mondayMidday);
  assert.strictEqual(mondayRes.isOpen, true);
  assert.strictEqual(mondayRes.canOrder, true);
  assert.strictEqual(mondayRes.status, "OPEN");
  console.log("  ✔ Evaluates OPEN during standard daytime operating hours");

  // 1.2 Closed outside hours on Monday (23:30 IST, after 22:00 close)
  const mondayLate = new Date("2026-10-26T18:00:00Z"); // 23:30 IST
  const lateRes = checkRestaurantAvailability(restaurantA, mondayLate);
  assert.strictEqual(lateRes.isOpen, false);
  assert.strictEqual(lateRes.canOrder, false);
  assert.strictEqual(lateRes.status, "CLOSED");
  assert.ok(lateRes.reason.includes("closed"));
  console.log("  ✔ Evaluates CLOSED after configured closing hour");

  // 1.3 Closed on Sunday (schedule specifies Sunday isOpen: false)
  const sundayMidday = new Date("2026-10-25T08:30:00Z"); // Sunday 14:00 IST
  const sundayRes = checkRestaurantAvailability(restaurantA, sundayMidday);
  assert.strictEqual(sundayRes.isOpen, false);
  assert.strictEqual(sundayRes.canOrder, false);
  assert.strictEqual(sundayRes.status, "CLOSED");
  assert.ok(sundayRes.reason.includes("closed on Sunday"));
  console.log("  ✔ Evaluates CLOSED on scheduled non-operating days");

  // 1.4 Midnight-crossing hours (Restaurant B: 18:00 to 02:00)
  const restaurantB = mockRestaurants[1];

  // 23:00 IST (Open)
  const bNight = new Date("2026-10-26T17:30:00Z"); // 23:00 IST
  const bNightRes = checkRestaurantAvailability(restaurantB, bNight);
  assert.strictEqual(bNightRes.isOpen, true, "Should be open at 23:00 for 18:00-02:00 schedule");

  // 01:15 IST (Open past midnight before 02:00)
  const bPastMidnight = new Date("2026-10-26T19:45:00Z"); // 01:15 IST next day
  const bPastMidnightRes = checkRestaurantAvailability(restaurantB, bPastMidnight);
  assert.strictEqual(bPastMidnightRes.isOpen, true, "Should be open at 01:15 for 18:00-02:00 schedule");

  // 03:30 IST (Closed)
  const bClosedEarly = new Date("2026-10-26T22:00:00Z"); // 03:30 IST
  const bClosedRes = checkRestaurantAvailability(restaurantB, bClosedEarly);
  assert.strictEqual(bClosedRes.isOpen, false, "Should be closed at 03:30 for 18:00-02:00 schedule");

  console.log("  ✔ Midnight-crossing operating hours handled cleanly across day boundaries");

  // 1.5 Emergency Pause overrides operating hours
  restaurantA.isOrderAcceptancePaused = true;
  restaurantA.pauseReason = "Kitchen maintenance until 4 PM";
  const pausedRes = checkRestaurantAvailability(restaurantA, mondayMidday);
  assert.strictEqual(pausedRes.isOpen, false);
  assert.strictEqual(pausedRes.status, "PAUSED");
  assert.strictEqual(pausedRes.canOrder, false);
  assert.strictEqual(pausedRes.reason, "Kitchen maintenance until 4 PM");
  console.log("  ✔ Emergency order pause immediately disables ordering with custom reason");

  // Reset pause
  restaurantA.isOrderAcceptancePaused = false;
  restaurantA.pauseReason = "";
}

// --- TEST 2: Backend Order Rejection When Closed or Paused ---
async function testBackendOrderRejectionWhenDisabled() {
  console.log("\n[2] Testing Backend Order Rejection When Orders Disabled...");

  const restaurantA = mockRestaurants[0];
  restaurantA.isOrderAcceptancePaused = true;
  restaurantA.pauseReason = "Temporarily overloaded with offline orders";

  const req = {
    user: mockUser,
    body: {
      restaurantId: restaurantA._id.toString(),
      orderItems: [
        { itemId: mockItems[0]._id.toString(), itemName: "Cold Coffee", itemPrice: 80, quantity: 1 }
      ],
      paymentMethod: "COD"
    }
  };

  try {
    await addOrderController(req);
    assert.fail("Should throw 400 when restaurant is paused");
  } catch (err) {
    assert.strictEqual(err.status, 400);
    assert.strictEqual(err.message, "Temporarily overloaded with offline orders");
    console.log("  ✔ Backend rejects order when order acceptance is paused");
  }

  // Resume orders
  restaurantA.isOrderAcceptancePaused = false;

  // Now place order when open
  const validRes = await addOrderController(req);
  assert.ok(validRes.order);
  assert.strictEqual(validRes.order.restaurantId.toString(), restaurantA._id.toString());
  assert.strictEqual(validRes.order.totalAmount, 80);
  console.log("  ✔ Successfully accepts order when restaurant is open and active");
  return validRes.order._id.toString();
}

// --- TEST 3: Multi-Restaurant Catalog, Price & Order Scoping ---
async function testMultiRestaurantScoping(orderAId) {
  console.log("\n[3] Testing Multi-Restaurant Data Isolation & Price Scoping...");

  // 3.1 Ordering Cold Coffee from Restaurant B computes Restaurant B's authoritative price (₹120 vs ₹80)
  const reqB = {
    user: mockUser,
    body: {
      restaurantId: restaurantBId.toString(),
      orderItems: [
        { itemId: mockItems[1]._id.toString(), itemName: "Cold Coffee", itemPrice: 999, quantity: 2 }
      ],
      paymentMethod: "UPI"
    }
  };

  const restaurantB = mockRestaurants[1];
  restaurantB.openingTime = "00:00";
  restaurantB.closingTime = "23:59";

  const resB = await addOrderController(reqB);
  assert.ok(resB.order);
  assert.strictEqual(resB.order.restaurantId.toString(), restaurantBId.toString());
  assert.strictEqual(resB.order.totalAmount, 240);
  console.log("  ✔ Server calculates totals from target restaurant's authoritative catalog (₹120 vs ₹80)");

  // 3.2 Admin order list scoping
  const adminAOrders = await getOrderController({ restaurantId: restaurantAId });
  assert.strictEqual(adminAOrders.length, 1);
  assert.strictEqual(adminAOrders[0].restaurantId.toString(), restaurantAId.toString());

  const adminBOrders = await getOrderController({ restaurantId: restaurantBId });
  assert.strictEqual(adminBOrders.length, 1);
  assert.strictEqual(adminBOrders[0].restaurantId.toString(), restaurantBId.toString());
  console.log("  ✔ Admin order lists strictly scoped to authorized restaurant (Zero cross-tenant leakage)");

  // 3.3 Cross-restaurant payment verification rejection
  try {
    await verifyPaymentController({
      user: { email: "adminA@serveo.test" },
      restaurantId: restaurantAId,
      body: {
        orderId: resB.order._id.toString(),
        verified: true
      }
    });
    assert.fail("Admin A should not be allowed to verify Restaurant B order");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.ok(err.message.includes("another restaurant"));
    console.log("  ✔ Rejects cross-tenant payment verification attempt with 403");
  }

  // 3.4 Cross-restaurant status update rejection
  try {
    await updateStatusController({
      restaurantId: restaurantAId,
      body: {
        id: resB.order._id.toString(),
        newStatus: "Completed"
      }
    });
    assert.fail("Admin A should not be allowed to update status of Restaurant B order");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.ok(err.message.includes("another restaurant"));
    console.log("  ✔ Rejects cross-tenant status update attempt with 403");
  }

  // 3.5 Authorized admin can verify their own restaurant's order
  const verifyRes = await verifyPaymentController({
    user: { email: "adminB@serveo.test" },
    restaurantId: restaurantBId,
    body: {
      orderId: resB.order._id.toString(),
      verified: true
    }
  });
  assert.strictEqual(verifyRes.order.paymentStatus, "Verified");
  assert.strictEqual(verifyRes.order.status, "Preparing");
  console.log("  ✔ Authorized administrator verifies their own restaurant's order successfully");
}

// --- TEST 4: Restaurant Settings Validation & Persistence ---
async function testRestaurantSettingsValidation() {
  console.log("\n[4] Testing Restaurant Settings Validation & Persistence...");

  const restaurantA = mockRestaurants[0];

  // Helper response mock
  function createMockRes() {
    return {
      statusCode: 200,
      jsonData: null,
      status(c) { this.statusCode = c; return this; },
      json(d) { this.jsonData = d; return this; }
    };
  }

  // 4.1 Reject empty name
  const resEmptyName = createMockRes();
  await updateAdminRestaurantSettingsController({
    restaurant: restaurantA,
    body: { name: "   " }
  }, resEmptyName);
  assert.strictEqual(resEmptyName.statusCode, 400);
  assert.strictEqual(resEmptyName.jsonData.error, "Restaurant name cannot be empty");
  console.log("  ✔ Validates and rejects empty restaurant names");

  // 4.2 Reject invalid time format
  const resBadTime = createMockRes();
  await updateAdminRestaurantSettingsController({
    restaurant: restaurantA,
    body: { openingTime: "25:70" }
  }, resBadTime);
  assert.strictEqual(resBadTime.statusCode, 400);
  assert.ok(resBadTime.jsonData.error.includes("HH:mm"));
  console.log("  ✔ Enforces valid 24-hour time format (HH:mm)");

  // 4.3 Reject invalid operating day
  const resBadDay = createMockRes();
  await updateAdminRestaurantSettingsController({
    restaurant: restaurantA,
    body: { operatingDays: ["Funday", "Monday"] }
  }, resBadDay);
  assert.strictEqual(resBadDay.statusCode, 400);
  assert.ok(resBadDay.jsonData.error.includes("Invalid day"));
  console.log("  ✔ Validates operating day selections");

  // 4.4 Successfully update valid business settings
  const resSuccess = createMockRes();
  await updateAdminRestaurantSettingsController({
    restaurant: restaurantA,
    body: {
      name: "Serveo Bistro Central",
      description: "Updated description for central food court",
      openingTime: "08:30",
      closingTime: "22:30",
      operatingDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
      currency: "INR",
      defaultEstimatedPrepTime: 22,
    }
  }, resSuccess);
  assert.strictEqual(resSuccess.statusCode, 200);
  assert.strictEqual(restaurantA.name, "Serveo Bistro Central");
  assert.strictEqual(restaurantA.openingTime, "08:30");
  assert.strictEqual(restaurantA.defaultEstimatedPrepTime, 22);
  console.log("  ✔ Successfully validates and applies business settings updates");
}

// --- TEST 5: Public QR Menu URL & Information Exposure Safety ---
async function testPublicQrMenuSafety() {
  console.log("\n[5] Testing Public QR Menu URL & Information Exposure Safety...");

  const restaurantA = mockRestaurants[0];

  function createMockRes() {
    return {
      statusCode: 200,
      jsonData: null,
      status(c) { this.statusCode = c; return this; },
      json(d) { this.jsonData = d; return this; }
    };
  }

  // 5.1 Public Info never exposes credentials, tokens, or admin emails
  const resInfo = createMockRes();
  await getPublicRestaurantInfoController({
    query: { slug: restaurantA.slug },
    params: {}
  }, resInfo);

  assert.strictEqual(resInfo.statusCode, 200);
  const pub = resInfo.jsonData.restaurant;
  assert.strictEqual(pub.name, restaurantA.name);
  assert.strictEqual(pub.currency, "INR");
  assert.strictEqual(pub.adminEmails, undefined, "Admin emails must NEVER be exposed publicly");
  assert.strictEqual(pub.adminUids, undefined, "Admin UIDs must NEVER be exposed publicly");
  console.log("  ✔ Public restaurant info strictly redacts admin accounts & credentials");

  // 5.2 Stable QR Code Generator
  const resQr = createMockRes();
  await generateRestaurantQrController({
    params: { identifier: restaurantA.slug },
    query: {},
    get: (h) => (h === "host" ? "serveo-foods.onrender.com" : ""),
    protocol: "https"
  }, resQr);

  assert.strictEqual(resQr.statusCode, 200);
  assert.strictEqual(resQr.jsonData.menuUrl, "https://serveo-foods.onrender.com/menu/serveo-a");
  assert.ok(resQr.jsonData.qrDataUrl.startsWith("data:image/png;base64,"));
  console.log("  ✔ Generates stable public menu URL and valid QR code image data");
}

async function run() {
  testOperatingHoursAndAvailability();
  const orderAId = await testBackendOrderRejectionWhenDisabled();
  await testMultiRestaurantScoping(orderAId);
  await testRestaurantSettingsValidation();
  await testPublicQrMenuSafety();

  console.log("\nAll Phase 4 Restaurant Onboarding & Isolation Backend Tests Passed Successfully!\n");
  process.exit(0);
}

run().catch(err => {
  console.error("Test error:", err);
  process.exit(1);
});
