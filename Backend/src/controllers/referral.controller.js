import { ReferralCode, ReferralRecord } from "../models/referral.models.js";
import { Restaurant } from "../models/restaurant.models.js";
import { User } from "../models/user.models.js";
import { Order } from "../models/order.models.js";
import { LoyaltyAccount, LoyaltyLedger } from "../models/loyalty.models.js";
import { Notification } from "../models/notification.models.js";
import crypto from "crypto";
import mongoose from "mongoose";

/**
 * Helper to generate a clean, human-readable unique referral code.
 */
function generateReferralCodeString(user) {
  let prefix = "SERVEO";
  if (user && user.fullName) {
    prefix = user.fullName.replace(/[^a-zA-Z]/g, "").toUpperCase().slice(0, 4) || "SERV";
  }
  const randomSuffix = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `${prefix}${randomSuffix}`;
}

/**
 * GET /user/referral
 * Customer endpoint: Get or generate unique referral code and view referral stats.
 */
export async function getCustomerReferralController(req, res) {
  try {
    const restaurantId = req.query.restaurantId;
    let userId = req.user?.uid ? (req.user._id || req.user.mongoId) : null;

    let userDoc = null;
    if (!userId && req.user?.uid) {
      userDoc = await User.findOne({ uid: req.user.uid });
      if (userDoc) userId = userDoc._id;
    } else if (userId) {
      userDoc = await User.findById(userId);
    }

    if (!userId) {
      return res.status(401).json({ error: "User account could not be identified" });
    }

    // Resolve restaurant
    let targetRestaurant = null;
    if (restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
      targetRestaurant = await Restaurant.findById(restaurantId);
    }
    if (!targetRestaurant) {
      targetRestaurant = (await Restaurant.findOne({ slug: "default" })) || (await Restaurant.findOne({}));
    }

    if (!targetRestaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    // Find or generate unique referral code for this user at this restaurant
    let referralCodeDoc = await ReferralCode.findOne({
      restaurantId: targetRestaurant._id,
      userId,
    });

    if (!referralCodeDoc) {
      let codeCandidate = generateReferralCodeString(userDoc);
      // Ensure global uniqueness for safety
      let attempts = 0;
      while ((await ReferralCode.findOne({ restaurantId: targetRestaurant._id, code: codeCandidate })) && attempts < 5) {
        codeCandidate = generateReferralCodeString(userDoc);
        attempts++;
      }

      referralCodeDoc = new ReferralCode({
        restaurantId: targetRestaurant._id,
        userId,
        code: codeCandidate,
      });
      await referralCodeDoc.save();
    }

    // Fetch referral records
    const referrals = await ReferralRecord.find({
      restaurantId: targetRestaurant._id,
      referrerUserId: userId,
    })
      .populate("refereeUserId", "fullName email")
      .sort({ createdAt: -1 })
      .lean();

    const config = targetRestaurant.referralProgram || {
      isEnabled: true,
      referrerPoints: 50,
      refereePoints: 25,
      minFirstOrderAmount: 100,
    };

    res.json({
      restaurantId: targetRestaurant._id,
      restaurantName: targetRestaurant.name,
      referralCode: referralCodeDoc.code,
      programConfig: {
        isEnabled: config.isEnabled,
        referrerPoints: config.referrerPoints,
        refereePoints: config.refereePoints,
        minOrderValue: config.minOrderValueForConversion || 100,
      },
      stats: {
        totalReferred: referrals.length,
        successfulConversions: referrals.filter((r) => r.status === "converted").length,
        totalPointsEarned: referrals.reduce((sum, r) => sum + (r.referrerPointsAwarded || 0), 0),
      },
      referrals: referrals.map((r) => ({
        id: r._id,
        friendName: r.refereeUserId?.fullName || "Friend",
        status: r.status,
        pointsAwarded: r.referrerPointsAwarded,
        rewardGrantedAt: r.rewardGrantedAt,
        createdAt: r.createdAt,
      })),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * POST /user/apply-referral
 * Customer endpoint: New customer inputs friend's referral code.
 */
export async function applyReferralCodeController(req, res) {
  try {
    const { referralCode, restaurantId } = req.body;
    if (!referralCode || typeof referralCode !== "string" || !referralCode.trim()) {
      return res.status(400).json({ error: "Referral code is required" });
    }

    const normalizedCode = referralCode.trim().toUpperCase();

    let userId = req.user?.uid ? (req.user._id || req.user.mongoId) : null;
    if (!userId && req.user?.uid) {
      const u = await User.findOne({ uid: req.user.uid });
      if (u) userId = u._id;
    }

    if (!userId) {
      return res.status(401).json({ error: "Authentication required" });
    }

    // Resolve restaurant
    let targetRestaurant = null;
    if (restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
      targetRestaurant = await Restaurant.findById(restaurantId);
    }
    if (!targetRestaurant) {
      targetRestaurant = (await Restaurant.findOne({ slug: "default" })) || (await Restaurant.findOne({}));
    }

    if (!targetRestaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    // 1. Find referral code document
    const refCodeDoc = await ReferralCode.findOne({
      restaurantId: targetRestaurant._id,
      code: normalizedCode,
    });

    if (!refCodeDoc) {
      return res.status(404).json({ error: `Referral code '${normalizedCode}' is invalid.` });
    }

    // 2. Prevent self-referral
    if (refCodeDoc.userId.toString() === userId.toString()) {
      return res.status(400).json({ error: "You cannot use your own referral code." });
    }

    // 3. Prevent duplicate referral: user can only be referred once per restaurant
    const existingRecord = await ReferralRecord.findOne({
      restaurantId: targetRestaurant._id,
      refereeUserId: userId,
    });
    if (existingRecord) {
      return res.status(400).json({
        error: "You have already applied a referral code at this restaurant.",
      });
    }

    // 4. Check if user already has completed orders (Must be a new customer)
    const priorCompletedOrders = await Order.countDocuments({
      restaurantId: targetRestaurant._id,
      userId: userId,
      status: { $in: ["Completed", "Collected"] },
    });

    if (priorCompletedOrders > 0) {
      return res.status(400).json({
        error: "Referral codes are only eligible for new customers who have not yet completed an order.",
      });
    }

    // 5. Create pending referral record
    const referralRecord = new ReferralRecord({
      restaurantId: targetRestaurant._id,
      referrerUserId: refCodeDoc.userId,
      refereeUserId: userId,
      referralCode: normalizedCode,
      status: "pending",
    });

    await referralRecord.save();

    // Increment referrer's totalReferred counter
    await ReferralCode.findByIdAndUpdate(refCodeDoc._id, { $inc: { totalReferred: 1 } });

    res.json({
      message: `Referral code applied! You and your friend will both earn bonus loyalty points when your first eligible order is completed.`,
      referralRecordId: referralRecord._id,
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * Internal conversion handler: Called when an order reaches Completed/Collected.
 * If user has a pending referral record at this restaurant, grants bonus points to both!
 */
export async function convertReferralOnFirstOrder(order) {
  if (!order || !order.restaurantId || !order.userId) return null;

  // Validate payment
  const isPaid =
    order.paymentStatus === "Verified" ||
    order.paymentMethod === "COD" ||
    order.paymentMethod === "Card";

  if (!isPaid) return null;

  const restaurant = await Restaurant.findById(order.restaurantId);
  if (!restaurant) return null;

  const config = restaurant.referralProgram || {
    isEnabled: true,
    referrerPoints: 50,
    refereePoints: 25,
    minOrderValueForConversion: 100,
  };

  if (config.isEnabled === false) return null;

  // Check minimum order value
  const minRequired = config.minOrderValueForConversion || 100;
  if ((order.totalAmount || 0) < minRequired) {
    return null;
  }

  // Find pending referral record
  const record = await ReferralRecord.findOne({
    restaurantId: order.restaurantId,
    refereeUserId: order.userId,
    status: "pending",
  });

  if (!record) return null;

  const referrerPoints = config.referrerPoints || 50;
  const refereePoints = config.refereePoints || 25;

  // 1. Award Referrer Points
  const referrerAccount = await LoyaltyAccount.findOneAndUpdate(
    { restaurantId: order.restaurantId, userId: record.referrerUserId },
    {
      $inc: {
        currentBalance: referrerPoints,
        totalEarned: referrerPoints,
      },
    },
    { new: true, upsert: true }
  );

  await LoyaltyLedger.create({
    restaurantId: order.restaurantId,
    userId: record.referrerUserId,
    orderId: order._id,
    transactionType: "BONUS_REFERRAL",
    points: referrerPoints,
    balanceAfter: referrerAccount.currentBalance,
    description: `Earned ${referrerPoints} bonus referral points for inviting a friend!`,
    metadata: { refereeUserId: order.userId, qualifyingOrderId: order._id },
  });

  // 2. Award Referee Points
  const refereeAccount = await LoyaltyAccount.findOneAndUpdate(
    { restaurantId: order.restaurantId, userId: order.userId },
    {
      $inc: {
        currentBalance: refereePoints,
        totalEarned: refereePoints,
      },
    },
    { new: true, upsert: true }
  );

  await LoyaltyLedger.create({
    restaurantId: order.restaurantId,
    userId: order.userId,
    orderId: order._id,
    transactionType: "BONUS_REFERRAL",
    points: refereePoints,
    balanceAfter: refereeAccount.currentBalance,
    description: `Welcome bonus! Earned ${refereePoints} loyalty points from referral code ${record.referralCode}.`,
    metadata: { referrerUserId: record.referrerUserId, qualifyingOrderId: order._id },
  });

  // 3. Mark Referral Record converted
  record.status = "converted";
  record.qualifyingOrderId = order._id;
  record.rewardGranted = true;
  record.rewardGrantedAt = new Date();
  record.referrerPointsAwarded = referrerPoints;
  record.refereePointsAwarded = refereePoints;
  await record.save();

  // Increment successfulConversions count on referrer's code
  await ReferralCode.findOneAndUpdate(
    { restaurantId: order.restaurantId, userId: record.referrerUserId },
    { $inc: { successfulConversions: 1 } }
  );

  // 4. Send Notifications
  try {
    const referrerUser = await User.findById(record.referrerUserId);
    if (referrerUser && referrerUser.notificationPreferences?.promotional !== false) {
      await Notification.create({
        restaurantId: order.restaurantId,
        userId: record.referrerUserId,
        title: "Referral Reward Earned!",
        body: `Your friend completed their first order! You earned ${referrerPoints} loyalty points. Current balance: ${referrerAccount.currentBalance} points.`,
        type: "referral_reward",
        metadata: { points: referrerPoints },
      });
    }

    const refereeUser = await User.findById(order.userId);
    if (refereeUser && refereeUser.notificationPreferences?.promotional !== false) {
      await Notification.create({
        restaurantId: order.restaurantId,
        userId: order.userId,
        title: "Referral Bonus Credited!",
        body: `Welcome! You earned ${refereePoints} bonus loyalty points on your first order. Current balance: ${refereeAccount.currentBalance} points.`,
        type: "referral_reward",
        metadata: { points: refereePoints },
      });
    }
  } catch (_) {}

  return record;
}

/**
 * GET /restaurant/admin/referrals
 * Admin endpoint: View referral program stats and conversion list.
 */
export async function getAdminReferralsController(req, res) {
  try {
    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const config = restaurant.referralProgram || {
      isEnabled: true,
      referrerPoints: 50,
      refereePoints: 25,
      minOrderValueForConversion: 100,
    };

    const referrals = await ReferralRecord.find({ restaurantId: req.restaurantId })
      .populate("referrerUserId", "fullName email")
      .populate("refereeUserId", "fullName email")
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    const totalReferrals = referrals.length;
    const convertedReferrals = referrals.filter((r) => r.status === "converted").length;
    const conversionRate = totalReferrals > 0 ? Math.round((convertedReferrals / totalReferrals) * 100) : 0;

    res.json({
      config,
      stats: {
        totalReferrals,
        convertedReferrals,
        conversionRate,
      },
      referrals,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * PUT /restaurant/admin/referrals
 * Admin endpoint: Update referral program settings.
 */
export async function updateAdminReferralsController(req, res) {
  try {
    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const { isEnabled, referrerPoints, refereePoints, minOrderValueForConversion } = req.body;

    if (!restaurant.referralProgram) {
      restaurant.referralProgram = {};
    }

    if (isEnabled !== undefined) restaurant.referralProgram.isEnabled = Boolean(isEnabled);
    if (referrerPoints !== undefined) restaurant.referralProgram.referrerPoints = Math.max(0, Number(referrerPoints) || 0);
    if (refereePoints !== undefined) restaurant.referralProgram.refereePoints = Math.max(0, Number(refereePoints) || 0);
    if (minOrderValueForConversion !== undefined) {
      restaurant.referralProgram.minOrderValueForConversion = Math.max(0, Number(minOrderValueForConversion) || 0);
    }

    await restaurant.save();
    res.json({
      message: "Referral program settings updated successfully",
      config: restaurant.referralProgram,
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}
