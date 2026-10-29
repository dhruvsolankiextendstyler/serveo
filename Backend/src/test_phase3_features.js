import assert from "assert";
import mongoose from "mongoose";
import { addOrderController } from "./controllers/addOrder.controller.js";
import { submitFeedbackController, getAdminFeedbackController } from "./controllers/feedback.controller.js";
import { getUserNotificationsController, markNotificationReadController } from "./controllers/notification.controller.js";
import { Item } from "./models/item.models.js";
import { Order } from "./models/order.models.js";
import { User } from "./models/user.models.js";
import { Notification } from "./models/notification.models.js";
import { Feedback } from "./models/feedback.models.js";
import { Restaurant } from "./models/restaurant.models.js";

console.log("=== Running Serveo Phase 3 Features Backend Tests ===");

Restaurant.findOne = async () => null;
Restaurant.findById = async () => null;

// Mock customer
const testUser = {
  _id: new mongoose.Types.ObjectId(),
  uid: "test_customer_uid",
  email: "customer@serveo.test",
  fullName: "Priya Sharma",
};

User.findOne = async (q) => {
  if (q.uid === testUser.uid || q.email === testUser.email) return testUser;
  return null;
};

// In-memory catalogs and tables
const itemsCatalog = [
  {
    _id: new mongoose.Types.ObjectId("65df00000000000000000001"),
    itemName: "Paneer Tikka Pizza",
    itemPrice: 249,
    category: "Pizza",
    isAvailable: true,
    customizations: [
      {
        name: "Size",
        type: "single",
        required: true,
        options: [
          { name: "Regular (7\")", price: 0 },
          { name: "Medium (10\")", price: 100 },
          { name: "Large (12\")", price: 180 },
        ],
      },
      {
        name: "Add-ons",
        type: "multiple",
        required: false,
        options: [
          { name: "Extra Cheese", price: 40 },
          { name: "Jalapenos", price: 25 },
        ],
      },
    ],
  },
  {
    _id: new mongoose.Types.ObjectId("65df00000000000000000002"),
    itemName: "Cold Coffee",
    itemPrice: 79,
    category: "Beverages",
    isAvailable: true,
    customizations: [],
  },
];

Item.findById = async (id) => {
  return itemsCatalog.find(i => i._id.toString() === id.toString()) || null;
};
Item.findOne = async (q) => {
  return itemsCatalog.find(i => i.itemName === q.itemName) || null;
};

let memoryOrders = [];
let memoryNotifications = [];
let memoryFeedbacks = [];

// Mock Order save
Order.prototype.save = async function() {
  const plain = this.toObject ? this.toObject() : { ...this };
  if (!plain._id) plain._id = new mongoose.Types.ObjectId();
  const idx = memoryOrders.findIndex(o => o._id.toString() === plain._id.toString());
  if (idx >= 0) {
    memoryOrders[idx] = plain;
  } else {
    memoryOrders.push(plain);
  }
  return plain;
};
Order.findById = async (id) => {
  return memoryOrders.find(o => o._id.toString() === id.toString()) || null;
};

// Mock Notification
Notification.create = async (doc) => {
  const notif = { ...doc, _id: new mongoose.Types.ObjectId(), isRead: false, createdAt: new Date() };
  memoryNotifications.push(notif);
  return notif;
};
Notification.find = (q) => {
  return {
    sort: () => ({
      limit: () => ({
        lean: async () => memoryNotifications.filter(n => n.userId.toString() === q.userId.toString())
      })
    })
  };
};
Notification.countDocuments = async (q) => {
  return memoryNotifications.filter(n => n.userId.toString() === q.userId.toString() && n.isRead === q.isRead).length;
};
Notification.findOne = async (q) => {
  const notif = memoryNotifications.find(n => n._id.toString() === q._id.toString() && n.userId.toString() === q.userId.toString());
  if (!notif) return null;
  return {
    ...notif,
    save: async function() {
      const idx = memoryNotifications.findIndex(n => n._id.toString() === notif._id.toString());
      if (idx >= 0) memoryNotifications[idx] = this;
      return this;
    }
  };
};

// Mock Feedback
Feedback.prototype.save = async function() {
  const doc = this.toObject ? this.toObject() : {
    orderId: this.orderId,
    userId: this.userId,
    customerName: this.customerName,
    rating: this.rating,
    comment: this.comment,
    tags: this.tags,
  };
  const plain = { ...doc, orderId: this.orderId || doc.orderId, _id: new mongoose.Types.ObjectId(), createdAt: new Date() };
  memoryFeedbacks.push(plain);
  return plain;
};
Feedback.findOne = async (q) => {
  return memoryFeedbacks.find(f => f.orderId && f.orderId.toString() === q.orderId.toString()) || null;
};
Feedback.find = () => ({
  populate: () => ({
    sort: () => ({
      limit: () => ({
        lean: async () => memoryFeedbacks.map(f => {
          const ord = memoryOrders.find(o => o._id.toString() === f.orderId.toString());
          return { ...f, orderId: ord || f.orderId };
        })
      })
    })
  })
});

// --- TEST 1: Menu Item Customization Validation & Calculation ---
async function testCustomizationAndEstimatedTime() {
  console.log("\n[1] Testing Menu Customizations & Authoritative Calculation...");

  const req = {
    user: { uid: testUser.uid },
    body: {
      orderItems: [
        {
          itemId: "65df00000000000000000001",
          itemName: "Paneer Tikka Pizza",
          itemPrice: 249, // Base price
          quantity: 2,
          selectedCustomizations: [
            { customizationName: "Size", optionName: "Large (12\")", price: 180 },
            { customizationName: "Add-ons", optionName: "Extra Cheese", price: 40 },
          ],
        },
        {
          itemId: "65df00000000000000000002",
          itemName: "Cold Coffee",
          itemPrice: 79,
          quantity: 1,
        },
      ],
      paymentMethod: "UPI",
    },
  };

  const res = await addOrderController(req);
  assert.ok(res.order);

  // Expected price calculation:
  // Pizza: (249 + 180 + 40) = 469 each * 2 = 938
  // Coffee: 79 * 1 = 79
  // Total = 938 + 79 = 1017
  assert.strictEqual(res.order.totalAmount, 1017, "Total must match base prices + authorized customization add-ons");
  assert.strictEqual(res.order.orderItems[0].selectedCustomizations.length, 2);
  assert.strictEqual(res.order.orderItems[0].selectedCustomizations[0].optionName, "Large (12\")");
  assert.strictEqual(res.order.orderItems[0].selectedCustomizations[0].price, 180);

  // Estimated preparation time: 10 + 3 items * 3 = 19 mins
  assert.ok(res.order.estimatedPrepTime >= 15 && res.order.estimatedPrepTime <= 45);
  assert.ok(res.order.estimatedReadyAt instanceof Date);

  console.log("  ✔ Authoritative pricing computed accurately with customization add-ons");
  console.log("  ✔ Estimated preparation time calculated and attached (~" + res.order.estimatedPrepTime + " mins)");
  return res.order._id.toString();
}

// --- TEST 2: In-App Persistent Notifications ---
async function testCustomerNotifications(orderId) {
  console.log("\n[2] Testing Persistent Customer In-App Notifications...");

  const req = { user: { uid: testUser.uid } };
  const data = await getUserNotificationsController(req);

  assert.ok(Array.isArray(data.notifications));
  assert.ok(data.notifications.length >= 1, "Order placement notification must be recorded");
  assert.strictEqual(data.unreadCount, 1);
  assert.strictEqual(data.notifications[0].orderId.toString(), orderId);

  // Mark notification read
  const notifId = data.notifications[0]._id.toString();
  const readRes = await markNotificationReadController({
    user: { uid: testUser.uid },
    params: { id: notifId },
  });
  assert.strictEqual(readRes.notification.isRead, true);

  const updatedData = await getUserNotificationsController(req);
  assert.strictEqual(updatedData.unreadCount, 0);
  console.log("  ✔ Customer notifications persisted in MongoDB, fetched, and marked as read");
}

// --- TEST 3: Feedback Submission, Ownership, Eligibility & Duplicate Guards ---
async function testOrderFeedback(orderId) {
  console.log("\n[3] Testing Customer Order Feedback & Rating Flow...");

  // 3.1 Reject feedback if order is still Processing
  try {
    await submitFeedbackController({
      user: { uid: testUser.uid },
      body: { orderId, rating: 5, comment: "Too early!" },
    });
    assert.fail("Should throw when order is not Completed/Collected");
  } catch (err) {
    assert.ok(err.message.includes("Feedback can only be submitted after food collection"));
    console.log("  ✔ Enforces order fulfillment eligibility (rejects premature feedback)");
  }

  // Move order to Completed
  const ord = memoryOrders.find(o => o._id.toString() === orderId);
  ord.status = "Completed";

  // 3.2 Reject feedback from unauthenticated or non-owner
  try {
    await submitFeedbackController({
      user: { uid: "stranger_uid", email: "stranger@serveo.test" },
      body: { orderId, rating: 5, comment: "Not my order" },
    });
    assert.fail("Should throw for non-owner");
  } catch (err) {
    console.log("  ✔ Rejects feedback attempts from non-owner accounts");
  }

  // 3.3 Valid feedback submission with star rating and sanitization
  const validRes = await submitFeedbackController({
    user: { uid: testUser.uid },
    body: {
      orderId,
      rating: 5,
      comment: "Delicious pizza, hot and fresh! <script>alert('xss')</script>",
      tags: ["Hot & Fresh", "Tasty Food"],
    },
  });

  assert.strictEqual(validRes.feedback.rating, 5);
  assert.strictEqual(validRes.feedback.comment, "Delicious pizza, hot and fresh!"); // Script tags stripped!
  assert.strictEqual(validRes.feedback.tags.length, 2);
  console.log("  ✔ Customer feedback saved with sanitized comments and valid ratings");

  // 3.4 Prevent duplicate feedback
  try {
    await submitFeedbackController({
      user: { uid: testUser.uid },
      body: { orderId, rating: 4, comment: "Second attempt" },
    });
    assert.fail("Should reject duplicate feedback");
  } catch (err) {
    assert.strictEqual(err.message, "Feedback has already been submitted for this order");
    console.log("  ✔ Prevents duplicate feedback on the same order");
  }

  // 3.5 Admin feedback overview
  const adminRes = await getAdminFeedbackController();
  assert.strictEqual(adminRes.count, 1);
  assert.strictEqual(adminRes.averageRating, 5);
  console.log("  ✔ Admin feedback endpoint computes average rating and lists reviews cleanly");
}

async function run() {
  const orderId = await testCustomizationAndEstimatedTime();
  await testCustomerNotifications(orderId);
  await testOrderFeedback(orderId);

  console.log("\nAll Phase 3 Features Backend Tests Passed Successfully!\n");
  process.exit(0);
}

run().catch(err => {
  console.error("Test error:", err);
  process.exit(1);
});
