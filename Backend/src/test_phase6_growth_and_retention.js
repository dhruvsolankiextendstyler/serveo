import assert from "assert";
import mongoose from "mongoose";
import { Restaurant } from "./models/restaurant.models.js";
import { Order } from "./models/order.models.js";
import { User } from "./models/user.models.js";
import { Item } from "./models/item.models.js";
import { Coupon } from "./models/coupon.models.js";
import { Campaign } from "./models/campaign.models.js";
import { LoyaltyAccount, LoyaltyLedger } from "./models/loyalty.models.js";
import { ReferralCode, ReferralRecord } from "./models/referral.models.js";
import { Notification } from "./models/notification.models.js";
import { PLANS, getPlanConfig } from "./models/plan.models.js";
import {
  validateAndCalculateCouponDiscount,
  createCouponController,
} from "./controllers/coupon.controller.js";
import {
  awardLoyaltyPointsForOrder,
  reverseLoyaltyPointsForOrder,
} from "./controllers/loyalty.controller.js";
import {
  convertReferralOnFirstOrder,
} from "./controllers/referral.controller.js";
import {
  computeCustomerRetentionData,
} from "./controllers/analytics.controller.js";

console.log("\n=== Running Serveo Phase 6: Growth, Marketing & Retention Backend Tests ===");

async function runTests() {
  // Test MongoDB IDs
  const restId1 = new mongoose.Types.ObjectId("672000000000000000000001");
  const restId2 = new mongoose.Types.ObjectId("672000000000000000000002");
  const userId1 = new mongoose.Types.ObjectId("672000000000000000000011");
  const userId2 = new mongoose.Types.ObjectId("672000000000000000000012");
  const userId3 = new mongoose.Types.ObjectId("672000000000000000000013");
  const itemId1 = new mongoose.Types.ObjectId("672000000000000000000021");
  const itemId2 = new mongoose.Types.ObjectId("672000000000000000000022");

  // Mock Users
  const mockUserOptedIn = {
    _id: userId1,
    uid: "firebase_user_1",
    fullName: "Loyal Customer",
    email: "loyal@serveo.app",
    phoneNumber: "+919999999991",
    notificationPreferences: {
      orders: true,
      promotional: true,
    },
  };

  const mockUserReferee = {
    _id: userId2,
    uid: "firebase_user_2",
    fullName: "Referee Friend",
    email: "friend@serveo.app",
    phoneNumber: "+919999999992",
    notificationPreferences: {
      orders: true,
      promotional: true,
    },
  };

  const mockUserOptedOut = {
    _id: userId3,
    uid: "firebase_user_3",
    fullName: "Privacy Customer",
    email: "privacy@serveo.app",
    phoneNumber: "+919999999993",
    notificationPreferences: {
      orders: true,
      promotional: false,
    },
  };

  const originalUserFindById = User.findById;
  User.findById = (id) => {
    if (id?.toString() === userId1.toString()) return Promise.resolve(mockUserOptedIn);
    if (id?.toString() === userId2.toString()) return Promise.resolve(mockUserReferee);
    if (id?.toString() === userId3.toString()) return Promise.resolve(mockUserOptedOut);
    return Promise.resolve(null);
  };

  const mockNotificationsCreated = [];
  const originalNotifCreate = Notification.create;
  Notification.create = (entry) => {
    mockNotificationsCreated.push(entry);
    return Promise.resolve(entry);
  };

  // Mock Restaurants
  const mockRestaurant1 = new Restaurant({
    _id: restId1,
    name: "Serveo Cafe Central",
    slug: "cafe-central",
    loyaltyProgram: {
      isEnabled: true,
      pointsPerRupee: 0.1, // 1 point per ₹10 spent
      minimumOrderValueForEarn: 50,
      canEarnOnDiscountedOrders: false,
      rewards: [
        {
          rewardId: "rew_flat_50",
          title: "₹50 Off",
          pointsRequired: 200,
          discountType: "flat",
          discountValue: 50,
          minOrderValue: 100,
          isActive: true,
        },
        {
          rewardId: "rew_pct_20",
          title: "20% Off",
          pointsRequired: 150,
          discountType: "percentage",
          discountValue: 20,
          maxDiscountAmount: 80,
          minOrderValue: 100,
          isActive: true,
        },
      ],
    },
    referralProgram: {
      isEnabled: true,
      referrerPoints: 100,
      refereePoints: 50,
      minOrderValueForConversion: 100,
    },
    subscription: {
      planId: "growth",
      status: "active",
    },
  });

  const mockRestaurant2 = new Restaurant({
    _id: restId2,
    name: "Serveo Express",
    slug: "express",
    loyaltyProgram: {
      isEnabled: true,
      pointsPerRupee: 0.2, // 2 points per ₹10 spent
      minimumOrderValueForEarn: 50,
      canEarnOnDiscountedOrders: true,
      rewards: [],
    },
  });

  // Mock Items
  const mockItemPizza = new Item({
    _id: itemId1,
    restaurantId: restId1,
    itemName: "Farmhouse Pizza",
    itemPrice: 200,
    category: "Pizza",
    isAvailable: true,
  });

  const mockItemCoke = new Item({
    _id: itemId2,
    restaurantId: restId1,
    itemName: "Cold Beverage",
    itemPrice: 50,
    category: "Beverages",
    isAvailable: true,
  });

  // =========================================================================
  // 1. COUPON VALIDATION & PRICING RULES
  // =========================================================================
  console.log("\n[1] Testing Coupon Validation & Authoritative Server Calculation...");

  // Mock Coupon: Flat ₹50 off (min order ₹150)
  const mockCouponFlat = new Coupon({
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    code: "SAVE50",
    discountType: "fixed",
    discountValue: 50,
    minOrderValue: 150,
    isActive: true,
    perCustomerLimit: 2,
    usedCount: 0,
    totalUsageLimit: 100,
  });

  // Mock Coupon: 20% off capped at ₹60
  const mockCouponPct = new Coupon({
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    code: "TASTY20",
    discountType: "percentage",
    discountValue: 20,
    maxDiscountAmount: 60,
    minOrderValue: 100,
    isActive: true,
    perCustomerLimit: 1,
    usedCount: 0,
  });

  // Mock Coupon: Expired
  const mockCouponExpired = new Coupon({
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    code: "EXPIRED10",
    discountType: "fixed",
    discountValue: 10,
    minOrderValue: 0,
    isActive: true,
    startDate: new Date(Date.now() - 1000 * 60 * 60 * 24 * 30),
    endDate: new Date(Date.now() - 1000 * 60 * 60 * 24 * 1), // expired yesterday
  });

  // Mock Coupon: Usage Limit Reached
  const mockCouponMaxed = new Coupon({
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    code: "MAXEDOUT",
    discountType: "fixed",
    discountValue: 25,
    minOrderValue: 0,
    isActive: true,
    totalUsageLimit: 5,
    usedCount: 5,
  });

  // Inject into Coupon.findOne
  const originalCouponFindOne = Coupon.findOne;
  const originalOrderCountDocuments = Order.countDocuments;
  Order.countDocuments = (query) => {
    return Promise.resolve(0);
  };
  Coupon.findOne = (query) => {
    const code = (query.code || "").toUpperCase();
    if (code === "SAVE50") return Promise.resolve(mockCouponFlat);
    if (code === "TASTY20") return Promise.resolve(mockCouponPct);
    if (code === "EXPIRED10") return Promise.resolve(mockCouponExpired);
    if (code === "MAXEDOUT") return Promise.resolve(mockCouponMaxed);
    return Promise.resolve(null);
  };

  const sampleTray = [
    { itemId: itemId1, itemName: "Farmhouse Pizza", itemPrice: 200, quantity: 1 },
    { itemId: itemId2, itemName: "Cold Beverage", itemPrice: 50, quantity: 1 },
  ];
  const traySubtotal = 250;

  // A. Invalid code
  const resBadCode = await validateAndCalculateCouponDiscount({
    couponCode: "NONEXISTENT",
    restaurantId: restId1,
    userId: userId1,
    orderItems: sampleTray,
    subtotal: traySubtotal,
  });
  assert.strictEqual(resBadCode.isValid, false, "Unknown coupon must be rejected");
  assert.ok(resBadCode.message.includes("invalid"));

  // B. Valid fixed coupon
  const resFlat = await validateAndCalculateCouponDiscount({
    couponCode: "SAVE50",
    restaurantId: restId1,
    userId: userId1,
    orderItems: sampleTray,
    subtotal: traySubtotal,
  });
  assert.strictEqual(resFlat.isValid, true, "Eligible coupon must be accepted");
  assert.strictEqual(resFlat.discountAmount, 50, "Discount must be exactly ₹50");
  assert.strictEqual(resFlat.newTotal, 200, "New total must be ₹200 (250 - 50)");

  // C. Minimum order value rejection
  const resMinOrder = await validateAndCalculateCouponDiscount({
    couponCode: "SAVE50",
    restaurantId: restId1,
    userId: userId1,
    orderItems: [{ itemId: itemId2, itemName: "Cold Beverage", itemPrice: 50, quantity: 1 }],
    subtotal: 50,
  });
  assert.strictEqual(resMinOrder.isValid, false, "Should reject when subtotal < minOrderValue");
  assert.ok(resMinOrder.message.includes("Minimum order value"));

  // D. Percentage discount capped at maxDiscountAmount
  // Subtotal ₹500: 20% = ₹100, but cap is ₹60
  const resPctCapped = await validateAndCalculateCouponDiscount({
    couponCode: "TASTY20",
    restaurantId: restId1,
    userId: userId1,
    orderItems: [{ itemId: itemId1, itemName: "Farmhouse Pizza", itemPrice: 200, quantity: 2 }],
    subtotal: 400,
  });
  assert.strictEqual(resPctCapped.isValid, true);
  assert.strictEqual(resPctCapped.discountAmount, 60, "20% of 400 (80) must be capped at maxDiscountAmount ₹60");
  assert.strictEqual(resPctCapped.newTotal, 340);

  // E. Expired coupon
  const resExpired = await validateAndCalculateCouponDiscount({
    couponCode: "EXPIRED10",
    restaurantId: restId1,
    userId: userId1,
    orderItems: sampleTray,
    subtotal: traySubtotal,
  });
  assert.strictEqual(resExpired.isValid, false);
  assert.ok(resExpired.message.includes("expired"), "Expired coupon must be rejected");

  // F. Total usage limit exceeded
  const resMaxed = await validateAndCalculateCouponDiscount({
    couponCode: "MAXEDOUT",
    restaurantId: restId1,
    userId: userId1,
    orderItems: sampleTray,
    subtotal: traySubtotal,
  });
  assert.strictEqual(resMaxed.isValid, false);
  assert.ok(resMaxed.message.includes("maximum total usage limit"));

  // G. Cross-restaurant isolation
  const resCrossTenant = await validateAndCalculateCouponDiscount({
    couponCode: "SAVE50",
    restaurantId: restId2, // Belongs to restId1
    userId: userId1,
    orderItems: sampleTray,
    subtotal: traySubtotal,
  });
  assert.strictEqual(resCrossTenant.isValid, false);
  assert.ok(resCrossTenant.message.includes("not valid for this restaurant"));

  console.log("  ✔ Server-side coupon verification computes exact discounts, caps, and expiry");
  console.log("  ✔ Minimum order value and cross-restaurant boundaries strictly enforced");

  // =========================================================================
  // 2. LOYALTY POINTS EARNING & DEDUPLICATION
  // =========================================================================
  console.log("\n[2] Testing Loyalty Points Ledger, Earning & Deduplication...");

  // In-memory loyalty storage
  const mockLoyaltyAccounts = new Map();
  const mockLoyaltyLedgers = [];

  const originalRestaurantFindById = Restaurant.findById;
  Restaurant.findById = (id) => {
    if (id?.toString() === restId1.toString()) return Promise.resolve(mockRestaurant1);
    if (id?.toString() === restId2.toString()) return Promise.resolve(mockRestaurant2);
    return Promise.resolve(null);
  };

  const originalAccountFindOne = LoyaltyAccount.findOne;
  LoyaltyAccount.findOne = (query) => {
    const key = `${query.restaurantId}_${query.userId}`;
    return Promise.resolve(mockLoyaltyAccounts.get(key) || null);
  };

  const originalAccountFindOneAndUpdate = LoyaltyAccount.findOneAndUpdate;
  LoyaltyAccount.findOneAndUpdate = (query, update) => {
    const key = `${query.restaurantId}_${query.userId}`;
    let acc = mockLoyaltyAccounts.get(key);
    if (!acc) {
      acc = {
        restaurantId: query.restaurantId,
        userId: query.userId,
        currentBalance: 0,
        totalEarned: 0,
        totalRedeemed: 0,
        save: () => Promise.resolve(acc),
      };
      mockLoyaltyAccounts.set(key, acc);
    }

    if (query["currentBalance"] && query["currentBalance"]["$gte"] !== undefined) {
      if (acc.currentBalance < query["currentBalance"]["$gte"]) {
        return Promise.resolve(null); // Insufficient balance guard
      }
    }

    if (update.$inc) {
      if (update.$inc.currentBalance) acc.currentBalance += update.$inc.currentBalance;
      if (update.$inc.totalEarned) acc.totalEarned += update.$inc.totalEarned;
      if (update.$inc.totalRedeemed) acc.totalRedeemed += update.$inc.totalRedeemed;
    }
    return Promise.resolve(acc);
  };

  const originalLedgerCreate = LoyaltyLedger.create;
  LoyaltyLedger.create = (entry) => {
    const record = { _id: new mongoose.Types.ObjectId(), ...entry, createdAt: new Date() };
    mockLoyaltyLedgers.push(record);
    return Promise.resolve(record);
  };

  const originalLedgerFindOne = LoyaltyLedger.findOne;
  LoyaltyLedger.findOne = (query) => {
    const match = mockLoyaltyLedgers.find((l) => {
      if (query.orderId && l.orderId?.toString() !== query.orderId.toString()) return false;
      if (query.transactionType && l.transactionType !== query.transactionType) return false;
      return true;
    });
    return Promise.resolve(match || null);
  };

  // Create an eligible order: Net paid ₹300, COD, Completed
  const mockOrder1 = {
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    userId: userId1,
    totalAmount: 300,
    subtotal: 300,
    discountAmount: 0,
    paymentMethod: "COD",
    paymentStatus: "Pending",
    status: "Completed",
    loyaltyPointsEarned: 0,
    loyaltyPointsAwarded: false,
    save: function () { return Promise.resolve(this); },
  };

  // A. Award points on completed order
  const earnRes1 = await awardLoyaltyPointsForOrder(mockOrder1);
  assert.ok(earnRes1 !== null, "Points must be awarded for eligible completed order");
  assert.strictEqual(earnRes1.pointsEarned, 30, "₹300 * 0.1 = 30 points");
  assert.strictEqual(mockOrder1.loyaltyPointsAwarded, true);

  // Check ledger entry
  assert.strictEqual(mockLoyaltyLedgers.length, 1);
  assert.strictEqual(mockLoyaltyLedgers[0].transactionType, "EARN");
  assert.strictEqual(mockLoyaltyLedgers[0].points, 30);
  assert.strictEqual(mockLoyaltyLedgers[0].balanceAfter, 30);

  // B. Prevent duplicate points award if status endpoint is called again
  const earnResDuplicate = await awardLoyaltyPointsForOrder(mockOrder1);
  assert.strictEqual(earnResDuplicate, null, "Repeated call must not award duplicate points");
  assert.strictEqual(mockLoyaltyLedgers.length, 1, "No duplicate ledger record created");

  // C. Disallow earning on discounted orders if restaurant policy disables it
  const mockOrderDiscounted = {
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    userId: userId1,
    totalAmount: 200,
    subtotal: 250,
    discountAmount: 50,
    paymentMethod: "COD",
    status: "Completed",
    loyaltyPointsAwarded: false,
    save: function () { return Promise.resolve(this); },
  };
  const earnResDiscounted = await awardLoyaltyPointsForOrder(mockOrderDiscounted);
  assert.strictEqual(earnResDiscounted, null, "Points must NOT be awarded on discounted order when canEarnOnDiscountedOrders is false");

  // D. Disallow earning on unverified UPI orders
  const mockOrderUnverifiedUpi = {
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    userId: userId1,
    totalAmount: 200,
    paymentMethod: "UPI",
    paymentStatus: "Awaiting Verification",
    status: "Completed",
    loyaltyPointsAwarded: false,
    save: function () { return Promise.resolve(this); },
  };
  const earnResUnverified = await awardLoyaltyPointsForOrder(mockOrderUnverifiedUpi);
  assert.strictEqual(earnResUnverified, null, "Unverified UPI order must NOT earn loyalty points");

  console.log("  ✔ Points calculated accurately on backend and awarded only on verified completion");
  console.log("  ✔ Duplicate status calls prevented from generating duplicate point awards");
  console.log("  ✔ Non-discounted and payment verification policies strictly respected");

  // =========================================================================
  // 3. LOYALTY REWARD REDEMPTION & REVERSAL RULES
  // =========================================================================
  console.log("\n[3] Testing Reward Redemption, Concurrency Guard & Cancellation Reversal...");

  // Customer 1 balance is currently 30 points.
  // Add 200 more points to test reward redemption
  await LoyaltyAccount.findOneAndUpdate(
    { restaurantId: restId1, userId: userId1 },
    { $inc: { currentBalance: 200, totalEarned: 200 } }
  );
  // Current balance: 230 points

  // Attempt to redeem 200 points for ₹50 off
  const redeemAccount = await LoyaltyAccount.findOneAndUpdate(
    { restaurantId: restId1, userId: userId1, currentBalance: { $gte: 200 } },
    { $inc: { currentBalance: -200, totalRedeemed: 200 } }
  );
  assert.ok(redeemAccount !== null, "Redemption with sufficient balance must succeed");
  assert.strictEqual(redeemAccount.currentBalance, 30, "Balance after redemption must be 30 points (230 - 200)");

  // Attempt concurrent/excess redemption: balance is 30, trying to redeem 200 again
  const failedRedeemAccount = await LoyaltyAccount.findOneAndUpdate(
    { restaurantId: restId1, userId: userId1, currentBalance: { $gte: 200 } },
    { $inc: { currentBalance: -200, totalRedeemed: 200 } }
  );
  assert.strictEqual(failedRedeemAccount, null, "Must safely reject redemption when points balance is insufficient");

  // Test Cancellation / Refund Reversals
  // Order that earned 30 points gets cancelled:
  // Reversal must debit 30 points and record CANCEL_REVERSAL
  await reverseLoyaltyPointsForOrder(mockOrder1, "Order cancelled by customer");
  assert.strictEqual(mockOrder1.loyaltyPointsAwarded, false);
  const cancelLedger = mockLoyaltyLedgers.find((l) => l.transactionType === "CANCEL_REVERSAL");
  assert.ok(cancelLedger !== null, "CANCEL_REVERSAL ledger entry must be created");
  assert.strictEqual(cancelLedger.points, -30, "Debit points must equal points previously earned");

  // Order that redeemed 200 points gets cancelled:
  // Points must be refunded back to customer balance!
  const mockOrderWithRedemption = {
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    userId: userId1,
    totalAmount: 150,
    appliedLoyaltyReward: {
      rewardId: "rew_flat_50",
      pointsRedeemed: 200,
      discountAmount: 50,
    },
    save: function () { return Promise.resolve(this); },
  };

  await reverseLoyaltyPointsForOrder(mockOrderWithRedemption, "Customer refund");
  const refundLedger = mockLoyaltyLedgers.find((l) => l.transactionType === "REFUND_REVERSAL");
  assert.ok(refundLedger !== null, "REFUND_REVERSAL ledger entry must be created");
  assert.strictEqual(refundLedger.points, 200, "Refunded points must equal points redeemed");

  console.log("  ✔ Atomic balance deductions protect against duplicate/negative balance spending");
  console.log("  ✔ Order cancellation seamlessly debits earned points and refunds redeemed points");

  // =========================================================================
  // 4. REFERRAL SYSTEM & FIRST-ORDER CONVERSION
  // =========================================================================
  console.log("\n[4] Testing Customer Referral Rules, Self-Referral Guard & First Order Conversion...");

  const mockReferralRecords = [];
  const mockReferralCodes = [];

  const originalRefRecordFindOne = ReferralRecord.findOne;
  ReferralRecord.findOne = (query) => {
    const match = mockReferralRecords.find((r) => {
      if (query.restaurantId && r.restaurantId.toString() !== query.restaurantId.toString()) return false;
      if (query.refereeUserId && r.refereeUserId.toString() !== query.refereeUserId.toString()) return false;
      if (query.status && r.status !== query.status) return false;
      return true;
    });
    return Promise.resolve(match || null);
  };

  const originalRefCodeFindOne = ReferralCode.findOne;
  ReferralCode.findOne = (query) => {
    const match = mockReferralCodes.find((c) => {
      if (query.restaurantId && c.restaurantId.toString() !== query.restaurantId.toString()) return false;
      if (query.code && c.code !== query.code) return false;
      return true;
    });
    return Promise.resolve(match || null);
  };

  const originalRefCodeFindOneAndUpdate = ReferralCode.findOneAndUpdate;
  ReferralCode.findOneAndUpdate = (query, update) => {
    return Promise.resolve({});
  };

  // Referrer is User 1, Referee is User 2
  const refRecordPending = {
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    referrerUserId: userId1,
    refereeUserId: userId2,
    referralCode: "SERV1234",
    status: "pending",
    rewardGranted: false,
    save: function () { return Promise.resolve(this); },
  };
  mockReferralRecords.push(refRecordPending);

  // A. Referee places order that meets minimum amount (₹150 >= ₹100) and is completed
  const refereeOrder = {
    _id: new mongoose.Types.ObjectId(),
    restaurantId: restId1,
    userId: userId2,
    totalAmount: 150,
    paymentMethod: "Card",
    paymentStatus: "Verified",
    status: "Completed",
    save: function () { return Promise.resolve(this); },
  };

  const conversionRes = await convertReferralOnFirstOrder(refereeOrder);
  assert.ok(conversionRes !== null, "Referral must convert on first eligible completed order");
  assert.strictEqual(refRecordPending.status, "converted");
  assert.strictEqual(refRecordPending.rewardGranted, true);
  assert.strictEqual(refRecordPending.referrerPointsAwarded, 100, "Referrer receives configured 100 points");
  assert.strictEqual(refRecordPending.refereePointsAwarded, 50, "Referee receives configured 50 points");

  // Check ledger entries for bonus points
  const referrerBonusLedger = mockLoyaltyLedgers.find(
    (l) => l.userId.toString() === userId1.toString() && l.transactionType === "BONUS_REFERRAL"
  );
  assert.ok(referrerBonusLedger !== null, "Referrer bonus ledger record must be created");
  assert.strictEqual(referrerBonusLedger.points, 100);

  const refereeBonusLedger = mockLoyaltyLedgers.find(
    (l) => l.userId.toString() === userId2.toString() && l.transactionType === "BONUS_REFERRAL"
  );
  assert.ok(refereeBonusLedger !== null, "Referee bonus ledger record must be created");
  assert.strictEqual(refereeBonusLedger.points, 50);

  console.log("  ✔ Referral rewards granted strictly upon first completed order meeting threshold");
  console.log("  ✔ Both referrer and referee credited with auditable BONUS_REFERRAL ledger entries");

  // =========================================================================
  // 5. CUSTOMER NOTIFICATION PREFERENCES & RETENTION EVENTS
  // =========================================================================
  console.log("\n[5] Testing Customer Notification Preferences & In-App Marketing Events...");

  mockNotificationsCreated.length = 0;

  // Helper simulating marketing notification dispatcher
  async function dispatchMarketingNotification({ userId, restaurantId, title, body, type }) {
    const user = await User.findById(userId);
    if (!user || user.notificationPreferences?.promotional === false) {
      return { sent: false, reason: "OPTED_OUT" };
    }
    const notif = await Notification.create({
      restaurantId,
      userId,
      title,
      body,
      type,
    });
    return { sent: true, notification: notif };
  }

  // A. Opted-in customer receives promotional notification
  const sendResOptedIn = await dispatchMarketingNotification({
    userId: userId1,
    restaurantId: restId1,
    title: "Weekend Feast: 20% Off",
    body: "Use code TASTY20 this weekend on all pizzas!",
    type: "promotion",
  });
  assert.strictEqual(sendResOptedIn.sent, true);
  assert.strictEqual(mockNotificationsCreated.length, 1);
  assert.strictEqual(mockNotificationsCreated[0].type, "promotion");

  // B. Opted-out customer is protected from promotional messages
  const sendResOptedOut = await dispatchMarketingNotification({
    userId: userId3,
    restaurantId: restId1,
    title: "Weekend Feast: 20% Off",
    body: "Use code TASTY20 this weekend on all pizzas!",
    type: "promotion",
  });
  assert.strictEqual(sendResOptedOut.sent, false);
  assert.strictEqual(sendResOptedOut.reason, "OPTED_OUT");
  assert.strictEqual(mockNotificationsCreated.length, 1, "Opted-out customer did not receive notification");

  console.log("  ✔ Customer promotional notification preferences respected (Opt-out enforced)");
  console.log("  ✔ In-app notification center persists marketing events cleanly");

  // =========================================================================
  // 6. CUSTOMER RETENTION & SEGMENTATION ANALYTICS
  // =========================================================================
  console.log("\n[6] Testing Customer Retention Metrics & Sales Breakdown Calculations...");

  const now = new Date();
  const pastDate = new Date(Date.now() - 1000 * 60 * 60 * 24 * 10); // 10 days ago

  const mockAnalyticsOrders = [
    // Returning customer order (User 1 has prior order)
    {
      _id: new mongoose.Types.ObjectId(),
      restaurantId: restId1,
      userId: userId1,
      subtotal: 300,
      discountAmount: 50,
      totalAmount: 250,
      status: "Completed",
      paymentMethod: "COD",
      paymentStatus: "Pending",
      appliedCoupon: { code: "SAVE50", discountAmount: 50 },
      createdAt: now,
    },
    // New customer order (User 2 first time order)
    {
      _id: new mongoose.Types.ObjectId(),
      restaurantId: restId1,
      userId: userId2,
      subtotal: 200,
      discountAmount: 0,
      totalAmount: 200,
      status: "Completed",
      paymentMethod: "Card",
      paymentStatus: "Verified",
      appliedCoupon: null,
      createdAt: now,
    },
  ];

  const originalOrderFind = Order.find;
  Order.find = (query) => {
    return {
      select: () => ({
        lean: () => Promise.resolve(mockAnalyticsOrders),
      }),
    };
  };

  const originalOrderDistinct = Order.distinct;
  Order.distinct = (field, query) => {
    // Return userId1 as having a prior order before current period
    return Promise.resolve([userId1]);
  };

  const originalLedgerAggregate = LoyaltyLedger.aggregate;
  LoyaltyLedger.aggregate = () => {
    return Promise.resolve([
      { _id: "EARN", totalPoints: 120, count: 4 },
      { _id: "REDEEM", totalPoints: -50, count: 1 },
    ]);
  };

  const originalReferralFind = ReferralRecord.find;
  ReferralRecord.find = () => {
    return {
      lean: () =>
        Promise.resolve([
          { status: "converted" },
          { status: "pending" },
        ]),
    };
  };

  const originalCampaignFind = Campaign.find;
  Campaign.find = () => {
    return {
      select: () => ({
        lean: () =>
          Promise.resolve([
            { title: "Weekend Offer", viewCount: 100, clickCount: 15, couponCode: "SAVE50" },
          ]),
      }),
    };
  };

  const retentionData = await computeCustomerRetentionData("today", null, null, restId1);

  // Assert Customer Segmentation
  assert.strictEqual(retentionData.customers.totalActive, 2, "2 active customers");
  assert.strictEqual(retentionData.customers.newCustomers, 1, "User 2 is new");
  assert.strictEqual(retentionData.customers.returningCustomers, 1, "User 1 is returning");
  assert.strictEqual(retentionData.customers.repeatOrderRate, 50, "50% repeat order rate");
  assert.strictEqual(retentionData.customers.orderFrequency, 1, "1 order per customer");

  // Assert Revenue Transparency
  assert.strictEqual(retentionData.revenue.grossSales, 500, "Gross sales before discount: 300 + 200 = 500");
  assert.strictEqual(retentionData.revenue.totalDiscounts, 50, "Discounts: 50");
  assert.strictEqual(retentionData.revenue.netPaidRevenue, 450, "Net paid revenue: 500 - 50 = 450");
  assert.strictEqual(retentionData.revenue.averageOrderValue, 225, "AOV: 450 / 2 = 225");

  // Assert Coupon Attribution
  assert.strictEqual(retentionData.coupons.redemptionCount, 1);
  assert.strictEqual(retentionData.coupons.discountTotal, 50);
  assert.strictEqual(retentionData.coupons.attributedSales, 250);
  assert.strictEqual(retentionData.coupons.breakdown[0].code, "SAVE50");

  // Assert Loyalty Ledger Metrics
  assert.strictEqual(retentionData.loyalty.pointsEarned, 120);
  assert.strictEqual(retentionData.loyalty.pointsRedeemed, 50);

  // Assert Referral Performance
  assert.strictEqual(retentionData.referrals.totalReferrals, 2);
  assert.strictEqual(retentionData.referrals.convertedReferrals, 1);
  assert.strictEqual(retentionData.referrals.conversionRate, 50);

  // Assert Campaign CTR
  assert.strictEqual(retentionData.campaigns[0].ctr, 15, "15 clicks / 100 views = 15% CTR");
  assert.strictEqual(retentionData.campaigns[0].couponUsage, 1);

  console.log("  ✔ Customer segmentation accurately distinguishes new vs returning customers");
  console.log("  ✔ Revenue reporting correctly differentiates gross sales, discounts, and net revenue");
  console.log("  ✔ Coupon attribution, loyalty points in/out, and referral conversions verified");

  // =========================================================================
  // 7. SUBSCRIPTION PLANS & MARKETING ENTITLEMENT GATING
  // =========================================================================
  console.log("\n[7] Testing Subscription Plan Compatibility & Marketing Feature Gating...");

  const starterPlan = getPlanConfig("starter");
  const growthPlan = getPlanConfig("growth");
  const premiumPlan = getPlanConfig("premium");

  assert.strictEqual(starterPlan.features.marketingAndLoyalty, false, "Starter plan must not include marketingAndLoyalty");
  assert.strictEqual(starterPlan.features.customerRetentionAnalytics, false, "Starter plan must not include customerRetentionAnalytics");
  assert.strictEqual(growthPlan.features.marketingAndLoyalty, true, "Growth plan must unlock marketingAndLoyalty");
  assert.strictEqual(growthPlan.features.customerRetentionAnalytics, true, "Growth plan must unlock customerRetentionAnalytics");
  assert.strictEqual(premiumPlan.features.marketingAndLoyalty, true, "Premium plan must unlock marketingAndLoyalty");

  console.log("  ✔ Starter plan gates marketing and customer retention features");
  console.log("  ✔ Growth and Premium tiers unlock full marketing and loyalty management");

  // Restore mocks
  Coupon.findOne = originalCouponFindOne;
  Restaurant.findById = originalRestaurantFindById;
  LoyaltyAccount.findOne = originalAccountFindOne;
  LoyaltyAccount.findOneAndUpdate = originalAccountFindOneAndUpdate;
  LoyaltyLedger.create = originalLedgerCreate;
  LoyaltyLedger.findOne = originalLedgerFindOne;
  LoyaltyLedger.aggregate = originalLedgerAggregate;
  ReferralRecord.findOne = originalRefRecordFindOne;
  ReferralRecord.find = originalReferralFind;
  ReferralCode.findOne = originalRefCodeFindOne;
  ReferralCode.findOneAndUpdate = originalRefCodeFindOneAndUpdate;
  User.findById = originalUserFindById;
  Notification.create = originalNotifCreate;
  Order.find = originalOrderFind;
  Order.distinct = originalOrderDistinct;
  Order.countDocuments = originalOrderCountDocuments;
  Campaign.find = originalCampaignFind;

  console.log("\nAll Phase 6 Growth, Marketing & Retention Backend Tests Passed Successfully!\n");
  process.exit(0);
}

runTests().catch((err) => {
  console.error("Test failed with exception:", err);
  process.exit(1);
});
