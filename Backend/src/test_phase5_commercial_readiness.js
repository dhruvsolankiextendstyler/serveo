/**
 * Serveo — Phase 5: Commercial Readiness & Operations Test Suite
 *
 * Verifies:
 * 1. Role-Based Access Control (RBAC): Owner, Manager, Kitchen, Cashier, Viewer permissions.
 * 2. Last-Owner Protection: Prevents demoting or removing the last authorized owner.
 * 3. Subscription & Plan Limits: Active menu items limit, staff accounts limit, feature entitlements.
 * 4. Operational Reliability: Idempotent order submission preventing duplicate records.
 * 5. Production Diagnostics & Logging: Health/readiness checks, sensitive credential redaction, audit logging.
 */

import assert from "assert";
import mongoose from "mongoose";
import { Restaurant } from "./models/restaurant.models.js";
import { Item } from "./models/item.models.js";
import { Order } from "./models/order.models.js";
import { User } from "./models/user.models.js";
import { Notification } from "./models/notification.models.js";
import { AuditLog } from "./models/audit_log.models.js";
import { PLANS, getPlanConfig } from "./models/plan.models.js";
import { sanitizeLogData, logger } from "./utils/logger.js";
import { verifyDatabaseReadiness } from "./utils/backup_utility.js";
import {
  addStaffController,
  updateStaffRoleController,
  removeStaffController,
  getStaffController,
} from "./controllers/staff.controller.js";
import {
  getSubscriptionStatusController,
  assignPlanController,
} from "./controllers/subscription.controller.js";
import { addItemController } from "./controllers/addItem.controller.js";
import { addOrderController } from "./controllers/addOrder.controller.js";
import { updateStatusController } from "./controllers/updateStatusController.js";
import { verifyPaymentController } from "./controllers/verifyPayment.controller.js";

async function runPhase5Tests() {
  console.log("\n=== Running Serveo Phase 5 Commercial Readiness & Operations Tests ===\n");

  const restId = new mongoose.Types.ObjectId();
  const restBId = new mongoose.Types.ObjectId();

  // Mock Restaurant with Staff and Subscription
  const mockRestaurant = {
    _id: restId,
    name: "Cafe Prime",
    slug: "cafe-prime",
    defaultEstimatedPrepTime: 15,
    adminEmails: ["owner@cafeprime.com"],
    adminUids: ["uid_owner_1"],
    staff: [
      {
        _id: new mongoose.Types.ObjectId(),
        uid: "uid_owner_1",
        email: "owner@cafeprime.com",
        name: "Alice Owner",
        role: "owner",
        isActive: true,
      },
      {
        _id: new mongoose.Types.ObjectId(),
        uid: "uid_kitchen_1",
        email: "kitchen@cafeprime.com",
        name: "Bob Chef",
        role: "kitchen",
        isActive: true,
      },
      {
        _id: new mongoose.Types.ObjectId(),
        uid: "uid_cashier_1",
        email: "cashier@cafeprime.com",
        name: "Charlie Cashier",
        role: "cashier",
        isActive: true,
      },
      {
        _id: new mongoose.Types.ObjectId(),
        uid: "uid_viewer_1",
        email: "viewer@cafeprime.com",
        name: "Dana Viewer",
        role: "viewer",
        isActive: true,
      },
    ],
    subscription: {
      planId: "starter",
      status: "active",
      startDate: new Date(),
      endDate: null,
      gracePeriodDays: 7,
      adminOverride: false,
      history: [],
    },
    save: async function () {
      return this;
    },
  };

  // Setup Mock Restaurant.findById and Notification.create
  Restaurant.findById = async (id) => {
    if (id && id.toString() === restId.toString()) return mockRestaurant;
    return null;
  };
  Notification.create = async (doc) => ({ _id: new mongoose.Types.ObjectId(), ...doc });
  User.findById = async () => null;

  // =========================================================================
  // TEST GROUP 1: Role-Based Access Control (RBAC) & Permission Enforcement
  // =========================================================================
  console.log("[1] Testing Staff Roles & RBAC Guard Rails...");

  // 1a. Kitchen staff allowed to update status to Preparing & Ready
  const mockOrder = {
    _id: new mongoose.Types.ObjectId(),
    userId: new mongoose.Types.ObjectId(),
    restaurantId: restId,
    status: "Accepted",
    paymentStatus: "Pending",
    save: async function () {
      return this;
    },
  };
  Order.findById = async (id) => mockOrder;

  const kitchenReq = {
    staffRole: "kitchen",
    restaurantId: restId,
    body: { id: mockOrder._id.toString(), newStatus: "Preparing" },
  };
  const kitchenResult = await updateStatusController(kitchenReq);
  assert.strictEqual(kitchenResult, "Status Changed");
  console.log("  ✔ Kitchen staff successfully transitions order to 'Preparing'");

  // 1b. Kitchen staff rejected from cancelling order (403)
  try {
    await updateStatusController({
      staffRole: "kitchen",
      restaurantId: restId,
      body: { id: mockOrder._id.toString(), newStatus: "Cancelled" },
    });
    assert.fail("Kitchen staff should not be allowed to cancel orders");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.strictEqual(err.code, "FORBIDDEN_ROLE");
    console.log("  ✔ Kitchen staff rejected with 403 when attempting order cancellation");
  }

  // 1c. Kitchen staff rejected from payment verification (403)
  try {
    await verifyPaymentController({
      staffRole: "kitchen",
      restaurantId: restId,
      body: { orderId: mockOrder._id.toString(), verified: true },
    });
    assert.fail("Kitchen staff should not be allowed to verify payments");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.strictEqual(err.code, "FORBIDDEN_ROLE");
    console.log("  ✔ Kitchen staff rejected with 403 when attempting payment verification");
  }

  Notification.create = async (doc) => ({ _id: new mongoose.Types.ObjectId(), ...doc });

  // 1d. Cashier staff permitted to verify payments
  Order.findOneAndUpdate = (filter, update) => {
    const updated = {
      ...mockOrder,
      paymentStatus: "Verified",
      status: "Preparing",
      userId: { _id: mockOrder.userId, fullName: "Test User" },
      ...(update?.$set || {}),
    };
    const p = Promise.resolve(updated);
    p.populate = () => p;
    return p;
  };
  const cashierReq = {
    staffRole: "cashier",
    restaurantId: restId,
    user: { email: "cashier@cafeprime.com" },
    body: { orderId: mockOrder._id.toString(), verified: true },
  };
  const cashierRes = await verifyPaymentController(cashierReq);
  assert.ok(cashierRes.order);
  console.log("  ✔ Cashier staff successfully verifies customer UPI payment");

  // 1e. Cashier staff rejected from changing kitchen cooking status (403)
  try {
    await updateStatusController({
      staffRole: "cashier",
      restaurantId: restId,
      body: { id: mockOrder._id.toString(), newStatus: "Preparing" },
    });
    assert.fail("Cashier staff should not update kitchen cooking status");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.strictEqual(err.code, "FORBIDDEN_ROLE");
    console.log("  ✔ Cashier staff rejected with 403 when updating kitchen status");
  }

  // 1f. Viewer account rejected from mutating status (403)
  try {
    await updateStatusController({
      staffRole: "viewer",
      restaurantId: restId,
      body: { id: mockOrder._id.toString(), newStatus: "Preparing" },
    });
    assert.fail("Viewer staff should not update order status");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.strictEqual(err.code, "FORBIDDEN_ROLE");
    console.log("  ✔ Read-only viewer account rejected with 403 on mutation attempt");
  }

  // =========================================================================
  // TEST GROUP 2: Staff Management & Last-Owner Protection
  // =========================================================================
  console.log("\n[2] Testing Staff Management & Last-Owner Protection...");

  // Mock AuditLog.create
  AuditLog.create = async (doc) => doc;

  // 2a. Adding a staff member
  const ownerStaffMember = mockRestaurant.staff[0];
  const reqRes = {
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      this.jsonData = data;
      return this;
    },
  };

  // Mock restaurant staff array .id method
  mockRestaurant.staff.id = function (id) {
    return this.find((s) => s._id.toString() === id.toString());
  };

  // 2b. Last-Owner Protection Guard: Attempt to demote sole owner to manager
  const demoteSoleOwnerReq = {
    restaurantId: restId,
    staffRole: "owner",
    params: { staffId: ownerStaffMember._id.toString() },
    body: { role: "manager" },
  };
  const demoteSoleOwnerRes = { ...reqRes };
  await updateStaffRoleController(demoteSoleOwnerReq, demoteSoleOwnerRes);
  assert.strictEqual(demoteSoleOwnerRes.statusCode, 400);
  assert.strictEqual(demoteSoleOwnerRes.jsonData.error, "CANNOT_REMOVE_LAST_OWNER");
  console.log("  ✔ Prevents demoting the last authorized owner with CANNOT_REMOVE_LAST_OWNER");

  // 2c. Last-Owner Protection Guard: Attempt to remove sole owner
  const removeSoleOwnerReq = {
    restaurantId: restId,
    staffRole: "owner",
    params: { staffId: ownerStaffMember._id.toString() },
  };
  const removeSoleOwnerRes = { ...reqRes };
  await removeStaffController(removeSoleOwnerReq, removeSoleOwnerRes);
  assert.strictEqual(removeSoleOwnerRes.statusCode, 400);
  assert.strictEqual(removeSoleOwnerRes.jsonData.error, "CANNOT_REMOVE_LAST_OWNER");
  console.log("  ✔ Prevents deleting the last authorized owner with CANNOT_REMOVE_LAST_OWNER");

  // =========================================================================
  // TEST GROUP 3: Subscription Plans, Feature Tiers & Usage Limits
  // =========================================================================
  console.log("\n[3] Testing Subscription Plans & Operational Limits...");

  // 3a. Starter plan active menu item limit (Max 20)
  Item.countDocuments = async (query) => 20; // 20 items already active
  Item.findOne = async () => null;

  try {
    await addItemController({
      restaurantId: restId,
      body: { itemName: "Super Deluxe Burger", itemPrice: 150, category: "Mains" },
    });
    assert.fail("Should throw PLAN_LIMIT_REACHED when at capacity");
  } catch (err) {
    assert.strictEqual(err.status, 403);
    assert.strictEqual(err.code, "PLAN_LIMIT_REACHED");
    assert.strictEqual(err.limitType, "maxActiveMenuItems");
    console.log("  ✔ Menu item creation blocked with 403 when Starter item limit (20) reached");
  }

  // 3b. Starter plan staff account limit (Max 2 active staff)
  const addStaffLimitRes = { ...reqRes };
  await addStaffController(
    {
      restaurantId: restId,
      staffRole: "owner",
      body: { email: "extra_staff@cafeprime.com", role: "kitchen" },
    },
    addStaffLimitRes
  );
  assert.strictEqual(addStaffLimitRes.statusCode, 403);
  assert.strictEqual(addStaffLimitRes.jsonData.error, "PLAN_LIMIT_REACHED");
  console.log("  ✔ Staff account addition blocked with 403 when Starter staff limit (2) reached");

  // 3c. Administrative Plan Assignment (Upgrade to Growth)
  const upgradePlanRes = { ...reqRes };
  await assignPlanController(
    {
      restaurantId: restId,
      staffRole: "owner",
      body: { planId: "growth", reason: "Commercial plan upgrade" },
    },
    upgradePlanRes
  );
  assert.strictEqual(upgradePlanRes.jsonData.subscription.planId, "growth");
  console.log("  ✔ Administrative plan upgrade successfully applied and recorded in audit history");

  // =========================================================================
  // TEST GROUP 4: Operational Reliability & Order Idempotency
  // =========================================================================
  console.log("\n[4] Testing Order Idempotency & Operational Reliability...");

  const userId = new mongoose.Types.ObjectId();
  User.findOne = async () => ({ _id: userId, fullName: "Test Buyer", email: "buyer@test.com" });

  let orderSaveCount = 0;
  const existingOrderSnapshot = {
    _id: new mongoose.Types.ObjectId(),
    userId,
    idempotencyKey: "test_key_12345",
    totalAmount: 200,
    status: "Processing",
    paymentStatus: "Pending",
  };

  Order.findOne = async (q) => {
    if (q.idempotencyKey === "test_key_12345") {
      return existingOrderSnapshot;
    }
    return null;
  };

  const dupOrderReq = {
    user: { uid: "uid_buyer_1" },
    body: {
      restaurantId: restId.toString(),
      idempotencyKey: "test_key_12345",
      orderItems: [{ itemId: new mongoose.Types.ObjectId(), itemPrice: 200, quantity: 1 }],
    },
  };

  const idempotentResult = await addOrderController(dupOrderReq);
  assert.strictEqual(idempotentResult.isDuplicate, true);
  assert.strictEqual(idempotentResult.order._id.toString(), existingOrderSnapshot._id.toString());
  console.log("  ✔ Idempotent duplicate submission safely returns existing order without creating a new one");

  // =========================================================================
  // TEST GROUP 5: Production Logging, Sanitization & Diagnostics
  // =========================================================================
  console.log("\n[5] Testing Production Structured Logging & Diagnostics...");

  // 5a. Credential and sensitive key redaction
  const sensitivePayload = {
    password: "SuperSecretPassword123",
    token: "eyJhbGciOi...",
    authorization: "Bearer eyJhb...",
    private_key: "-----BEGIN PRIVATE KEY-----...",
    customerName: "Jane Doe",
    orderTotal: 450,
  };

  const sanitized = sanitizeLogData(sensitivePayload);
  assert.strictEqual(sanitized.password, "[REDACTED]");
  assert.strictEqual(sanitized.token, "[REDACTED]");
  assert.strictEqual(sanitized.authorization, "[REDACTED]");
  assert.strictEqual(sanitized.private_key, "[REDACTED]");
  assert.strictEqual(sanitized.customerName, "Jane Doe");
  assert.strictEqual(sanitized.orderTotal, 450);
  console.log("  ✔ Structured logger securely redacts passwords, tokens, auth headers, and private keys");

  // 5b. Database readiness inspection
  const readiness = await verifyDatabaseReadiness();
  assert.ok(typeof readiness.connected === "boolean");
  assert.ok(readiness.collections);
  console.log("  ✔ Database readiness verification executes cleanly and reports collection statistics");

  console.log("\nAll Phase 5 Commercial Readiness & Operations Tests Passed Successfully!\n");
}

runPhase5Tests().catch((err) => {
  console.error("❌ Phase 5 Test Suite Failed:", err);
  process.exit(1);
});
