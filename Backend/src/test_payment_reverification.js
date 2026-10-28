import assert from "assert";
import mongoose from "mongoose";
import { claimPaymentController } from "./controllers/claimPayment.controller.js";
import { verifyPaymentController } from "./controllers/verifyPayment.controller.js";
import { Order } from "./models/order.models.js";
import { User } from "./models/user.models.js";

console.log("=== Running Serveo Payment Re-Verification Backend Tests ===");

// Helper mock user
const customerUser = {
  _id: new mongoose.Types.ObjectId(),
  uid: "cust_firebase_uid_123",
  email: "customer@example.com",
  fullName: "Aarav Patel",
};

const otherCustomerUser = {
  _id: new mongoose.Types.ObjectId(),
  uid: "other_firebase_uid_456",
  email: "other@example.com",
  fullName: "Other Customer",
};

const adminUser = {
  uid: "admin_firebase_uid",
  email: "admin123@ad.in",
};

import { Notification } from "./models/notification.models.js";

// Mock Notification.create so tests don't timeout on DB buffering
Notification.create = async () => ({ _id: new mongoose.Types.ObjectId() });

// Mock User.findOne
User.findOne = async (query) => {
  if (query.uid === customerUser.uid || query.email === customerUser.email) return customerUser;
  if (query.uid === otherCustomerUser.uid || query.email === otherCustomerUser.email) return otherCustomerUser;
  if (query.email === adminUser.email) return { ...adminUser, _id: new mongoose.Types.ObjectId() };
  return null;
};

// In-memory order store
let mockDbOrders = new Map();

Order.findById = async (id) => {
  const o = mockDbOrders.get(id.toString());
  return o ? { ...o } : null;
};

Order.findOneAndUpdate = (filter, update, options) => {
  const id = filter._id?.toString() || filter._id;
  const existing = mockDbOrders.get(id);
  if (!existing) {
    const query = Promise.resolve(null);
    query.populate = () => query;
    return query;
  }

  // Filter checks
  if (filter.paymentStatus && filter.paymentStatus.$ne && existing.paymentStatus === filter.paymentStatus.$ne) {
    const query = Promise.resolve(null);
    query.populate = () => query;
    return query;
  }
  if (filter.status && filter.status.$nin && filter.status.$nin.includes(existing.status)) {
    const query = Promise.resolve(null);
    query.populate = () => query;
    return query;
  }

  const updated = { ...existing };
  if (update.$set) {
    Object.assign(updated, update.$set);
  }
  if (update.$push) {
    for (const key of Object.keys(update.$push)) {
      if (!Array.isArray(updated[key])) updated[key] = [];
      updated[key].push(update.$push[key]);
    }
  }

  mockDbOrders.set(id, updated);
  const query = Promise.resolve(updated);
  query.populate = () => query;
  return query;
};

// --- TEST 1: Initial UPI Verification Request ---
async function testInitialUpiVerification() {
  console.log("\n[1] Testing Initial UPI Verification Request...");

  const orderId = new mongoose.Types.ObjectId().toString();
  const testOrder = {
    _id: new mongoose.Types.ObjectId(orderId),
    userId: customerUser._id,
    orderItems: [{ itemId: new mongoose.Types.ObjectId(), itemName: "Veggie Burger", itemPrice: 120, quantity: 1 }],
    totalAmount: 120,
    paymentMethod: "UPI",
    paymentStatus: "Pending",
    status: "Processing",
    verificationAttempts: [],
  };
  mockDbOrders.set(orderId, testOrder);

  const req = {
    user: { uid: customerUser.uid },
    body: { orderId },
  };

  const res = await claimPaymentController(req);
  assert.ok(res.order);
  assert.strictEqual(res.order.paymentStatus, "Awaiting Verification");
  assert.strictEqual(res.order.status, "Pending Verification");
  assert.strictEqual(res.order.verificationAttempts.length, 1);
  assert.strictEqual(res.order.verificationAttempts[0].attemptNumber, 1);
  assert.strictEqual(res.order.verificationAttempts[0].status, "Pending");
  assert.ok(res.order.paymentClaimedAt);
  console.log("  ✔ Customer successfully submits initial verification request");
  return orderId;
}

// --- TEST 2: Admin Rejection with Reason ---
async function testAdminRejectionWithReason(orderId) {
  console.log("\n[2] Testing Admin Rejection with Reason...");

  const req = {
    user: adminUser,
    body: {
      orderId,
      verified: false,
      rejectionReason: "UTR mismatch / Bank amount not received",
    },
  };

  const res = await verifyPaymentController(req);
  assert.ok(res.order);
  assert.strictEqual(res.order.paymentStatus, "Rejected");
  assert.strictEqual(res.order.status, "Payment Rejected");
  assert.strictEqual(res.order.paymentRejectionReason, "UTR mismatch / Bank amount not received");
  assert.strictEqual(res.order.verifiedBy, adminUser.email);
  assert.strictEqual(res.order.verificationAttempts.length, 1);
  assert.strictEqual(res.order.verificationAttempts[0].status, "Rejected");
  assert.strictEqual(res.order.verificationAttempts[0].rejectionReason, "UTR mismatch / Bank amount not received");
  console.log("  ✔ Admin rejects payment with reason; attempt 1 recorded as Rejected");
}

// --- TEST 3: Customer Re-Submission for Same Order ---
async function testCustomerResubmission(orderId) {
  console.log("\n[3] Testing Customer Re-Submission for Same Order...");

  const req = {
    user: { uid: customerUser.uid },
    body: { orderId },
  };

  const res = await claimPaymentController(req);
  assert.ok(res.order);
  assert.strictEqual(res.order._id.toString(), orderId, "Order ID must remain unchanged");
  assert.strictEqual(res.order.paymentStatus, "Awaiting Verification");
  assert.strictEqual(res.order.status, "Pending Verification");
  assert.strictEqual(res.order.verificationAttempts.length, 2, "Must preserve previous attempt and record attempt 2");
  assert.strictEqual(res.order.verificationAttempts[0].status, "Rejected", "Previous attempt preserved as Rejected");
  assert.strictEqual(res.order.verificationAttempts[1].attemptNumber, 2);
  assert.strictEqual(res.order.verificationAttempts[1].status, "Pending");
  assert.ok(res.message.includes("resubmitted"));
  console.log("  ✔ Customer resubmits verification: Order ID unchanged, history preserved, attempt 2 created");
}

// --- TEST 4: Duplicate Submission Prevention While Awaiting Verification ---
async function testDuplicateSubmissionPrevention(orderId) {
  console.log("\n[4] Testing Duplicate Submission Prevention...");

  const req = {
    user: { uid: customerUser.uid },
    body: { orderId },
  };

  try {
    await claimPaymentController(req);
    assert.fail("Should throw when verification is already pending");
  } catch (err) {
    assert.strictEqual(err.message, "Payment verification is already pending store review");
    console.log("  ✔ Prevents duplicate/concurrent active verification requests");
  }
}

// --- TEST 5: Admin Approval of Resubmitted Attempt ---
async function testAdminApprovalOfResubmittedAttempt(orderId) {
  console.log("\n[5] Testing Admin Approval of Resubmitted Attempt...");

  const req = {
    user: adminUser,
    body: {
      orderId,
      verified: true,
    },
  };

  const res = await verifyPaymentController(req);
  assert.ok(res.order);
  assert.strictEqual(res.order.paymentStatus, "Verified");
  assert.strictEqual(res.order.status, "Preparing");
  assert.strictEqual(res.order.verificationAttempts.length, 2);
  assert.strictEqual(res.order.verificationAttempts[0].status, "Rejected");
  assert.strictEqual(res.order.verificationAttempts[1].status, "Verified");
  assert.strictEqual(res.order.verificationAttempts[1].reviewedBy, adminUser.email);
  assert.ok(res.order.estimatedPrepTime > 0, "Calculates estimated preparation time");
  console.log("  ✔ Admin verifies attempt 2: Payment marked Verified, status moved to Preparing");
}

// --- TEST 6: Rejection of Resubmission When Already Verified ---
async function testResubmissionWhenAlreadyVerified(orderId) {
  console.log("\n[6] Testing Resubmission When Already Verified...");

  const req = {
    user: { uid: customerUser.uid },
    body: { orderId },
  };

  const res = await claimPaymentController(req);
  assert.strictEqual(res.message, "Order payment has already been verified");
  assert.strictEqual(res.order.paymentStatus, "Verified");
  console.log("  ✔ Rejects re-verification once payment is already Verified");
}

// --- TEST 7: Unauthorized Attempts by Another Customer ---
async function testUnauthorizedResubmission(orderId) {
  console.log("\n[7] Testing Unauthorized Order Claim...");

  const req = {
    user: { uid: otherCustomerUser.uid },
    body: { orderId },
  };

  try {
    await claimPaymentController(req);
    assert.fail("Should throw on unauthorized access");
  } catch (err) {
    assert.strictEqual(err.message, "Unauthorized to claim payment for this order");
    assert.strictEqual(err.status, 403);
    console.log("  ✔ Rejects claim attempts by unauthorized users with 403");
  }
}

// --- TEST 8: Unauthorized Customer Attempt to Call verify-payment ---
async function testUnauthorizedAdminAction(orderId) {
  console.log("\n[8] Testing Double Review / Verification Guard...");

  // If already verified, verifyPaymentController rejects re-verification
  const req = {
    user: adminUser,
    body: { orderId, verified: true },
  };

  try {
    await verifyPaymentController(req);
    assert.fail("Should prevent re-verifying an already verified order");
  } catch (err) {
    assert.strictEqual(err.message, "This order has already been verified");
    console.log("  ✔ Prevents accidental double-action on already verified orders");
  }
}

// --- TEST 9: Ineligible Orders (COD and Cancelled) ---
async function testIneligibleOrders() {
  console.log("\n[9] Testing Ineligible Orders (COD and Cancelled)...");

  // 9.1 COD order
  const codOrderId = new mongoose.Types.ObjectId().toString();
  mockDbOrders.set(codOrderId, {
    _id: new mongoose.Types.ObjectId(codOrderId),
    userId: customerUser._id,
    paymentMethod: "COD",
    paymentStatus: "Pending",
    status: "Processing",
  });

  try {
    await claimPaymentController({ user: { uid: customerUser.uid }, body: { orderId: codOrderId } });
    assert.fail("Should throw on COD order");
  } catch (err) {
    assert.strictEqual(err.message, "Payment verification is not applicable to COD orders");
    console.log("  ✔ Rejects verification claims on COD orders");
  }

  // 9.2 Cancelled order
  const cancelledOrderId = new mongoose.Types.ObjectId().toString();
  mockDbOrders.set(cancelledOrderId, {
    _id: new mongoose.Types.ObjectId(cancelledOrderId),
    userId: customerUser._id,
    paymentMethod: "UPI",
    paymentStatus: "Pending",
    status: "Cancelled",
  });

  try {
    await claimPaymentController({ user: { uid: customerUser.uid }, body: { orderId: cancelledOrderId } });
    assert.fail("Should throw on Cancelled order");
  } catch (err) {
    assert.strictEqual(err.message, "Cannot submit payment verification for a cancelled order");
    console.log("  ✔ Rejects verification claims on Cancelled orders");
  }
}

// --- TEST 10: Legacy Order Compatibility ---
async function testLegacyOrderCompatibility() {
  console.log("\n[10] Testing Legacy Order Compatibility...");

  const legacyOrderId = new mongoose.Types.ObjectId().toString();
  mockDbOrders.set(legacyOrderId, {
    _id: new mongoose.Types.ObjectId(legacyOrderId),
    userId: customerUser._id,
    paymentMethod: "UPI",
    paymentStatus: "Rejected",
    status: "Payment Rejected",
    // No verificationAttempts array or paymentRejectionReason exists!
  });

  const res = await claimPaymentController({
    user: { uid: customerUser.uid },
    body: { orderId: legacyOrderId },
  });

  assert.ok(res.order);
  assert.strictEqual(res.order.paymentStatus, "Awaiting Verification");
  assert.strictEqual(res.order.verificationAttempts.length, 1);
  assert.strictEqual(res.order.verificationAttempts[0].attemptNumber, 1);
  console.log("  ✔ Legacy orders with missing optional fields handled cleanly without errors");
}

async function runAll() {
  const orderId = await testInitialUpiVerification();
  await testAdminRejectionWithReason(orderId);
  await testCustomerResubmission(orderId);
  await testDuplicateSubmissionPrevention(orderId);
  await testAdminApprovalOfResubmittedAttempt(orderId);
  await testResubmissionWhenAlreadyVerified(orderId);
  await testUnauthorizedResubmission(orderId);
  await testUnauthorizedAdminAction(orderId);
  await testIneligibleOrders();
  await testLegacyOrderCompatibility();

  console.log("\nAll Payment Re-Verification Backend Unit & Security Tests Passed Successfully!\n");
  process.exit(0);
}

runAll().catch(err => {
  console.error("Test failed:", err);
  process.exit(1);
});
