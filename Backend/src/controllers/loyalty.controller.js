import { LoyaltyAccount, LoyaltyLedger } from "../models/loyalty.models.js";
import { Restaurant } from "../models/restaurant.models.js";
import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { Notification } from "../models/notification.models.js";
import mongoose from "mongoose";

/**
 * GET /restaurant/:restaurantId/loyalty
 * Customer endpoint: View current loyalty points, transaction history, and available rewards.
 */
export async function getCustomerLoyaltyController(req, res) {
  try {
    const restaurantId = req.params.restaurantId || req.query.restaurantId;
    let userId = req.user?.uid ? (req.user._id || req.user.mongoId) : null;

    if (!userId && req.user?.uid) {
      const userDoc = await User.findOne({ uid: req.user.uid });
      if (userDoc) userId = userDoc._id;
    }

    if (!userId) {
      return res.status(401).json({ error: "User account could not be identified" });
    }

    // Resolve target restaurant
    let restaurant = null;
    if (restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
      restaurant = await Restaurant.findById(restaurantId);
    }
    if (!restaurant) {
      restaurant = await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
    }

    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    // Find or create customer loyalty account for this restaurant
    let account = await LoyaltyAccount.findOne({ restaurantId: restaurant._id, userId });
    if (!account) {
      account = new LoyaltyAccount({
        restaurantId: restaurant._id,
        userId,
        currentBalance: 0,
        totalEarned: 0,
        totalRedeemed: 0,
      });
      await account.save();
    }

    // Fetch ledger transaction history
    const ledger = await LoyaltyLedger.find({ restaurantId: restaurant._id, userId })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const config = restaurant.loyaltyProgram || {
      isEnabled: true,
      pointsPerRupee: 0.1,
      minimumOrderValueForEarn: 50,
      canEarnOnDiscountedOrders: false,
      rewards: [],
    };

    const activeRewards = (config.rewards || []).filter((r) => r.isActive !== false);

    res.json({
      restaurantId: restaurant._id,
      restaurantName: restaurant.name,
      loyaltyProgram: {
        isEnabled: config.isEnabled,
        pointsPerRupee: config.pointsPerRupee,
        minimumOrderValueForEarn: config.minimumOrderValueForEarn,
        canEarnOnDiscountedOrders: config.canEarnOnDiscountedOrders,
      },
      currentBalance: account.currentBalance,
      totalEarned: account.totalEarned,
      totalRedeemed: account.totalRedeemed,
      availableRewards: activeRewards.map((r) => ({
        rewardId: r.rewardId,
        title: r.title,
        description: r.description,
        pointsRequired: r.pointsRequired,
        discountType: r.discountType,
        discountValue: r.discountValue,
        maxDiscountAmount: r.maxDiscountAmount,
        minOrderValue: r.minOrderValue,
        canRedeem: account.currentBalance >= r.pointsRequired,
        pointsNeeded: Math.max(0, r.pointsRequired - account.currentBalance),
      })),
      history: ledger.map((entry) => ({
        id: entry._id,
        transactionType: entry.transactionType,
        points: entry.points,
        balanceAfter: entry.balanceAfter,
        description: entry.description,
        createdAt: entry.createdAt,
        orderId: entry.orderId,
      })),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * Internal helper to award points once an order is marked Completed or Collected.
 * Auditable, ledger-backed, strictly prevents duplicate point awards.
 */
export async function awardLoyaltyPointsForOrder(order) {
  if (!order || !order.restaurantId || !order.userId) return null;

  // Prevent duplicate point awards if called repeatedly
  if (order.loyaltyPointsAwarded) {
    return null;
  }

  // Check if an EARN ledger record already exists for this order
  const existingLedger = await LoyaltyLedger.findOne({
    orderId: order._id,
    transactionType: "EARN",
  });
  if (existingLedger) {
    order.loyaltyPointsAwarded = true;
    await order.save();
    return null;
  }

  // Validate payment status: must not be Rejected or Unverified UPI
  const isPaidOrVerified =
    order.paymentStatus === "Verified" ||
    order.paymentMethod === "COD" ||
    order.paymentMethod === "Card";

  if (!isPaidOrVerified) {
    return null;
  }

  const restaurant = await Restaurant.findById(order.restaurantId);
  if (!restaurant) return null;

  const config = restaurant.loyaltyProgram;
  if (!config || config.isEnabled === false) {
    return null;
  }

  // Check if points can be earned on discounted orders
  const hasDiscount = (order.discountAmount || 0) > 0;
  if (hasDiscount && config.canEarnOnDiscountedOrders === false) {
    return null;
  }

  // Check minimum order value
  const netPaidAmount = Number(order.totalAmount || 0);
  if (config.minimumOrderValueForEarn > 0 && netPaidAmount < config.minimumOrderValueForEarn) {
    return null;
  }

  // Calculate points
  const pointsRate = Number(config.pointsPerRupee) || 0.1;
  const pointsEarned = Math.floor(netPaidAmount * pointsRate);

  if (pointsEarned <= 0) {
    return null;
  }

  // Atomically update LoyaltyAccount
  const account = await LoyaltyAccount.findOneAndUpdate(
    { restaurantId: order.restaurantId, userId: order.userId },
    {
      $inc: {
        currentBalance: pointsEarned,
        totalEarned: pointsEarned,
      },
    },
    { new: true, upsert: true }
  );

  // Write audit ledger record
  await LoyaltyLedger.create({
    restaurantId: order.restaurantId,
    userId: order.userId,
    orderId: order._id,
    transactionType: "EARN",
    points: pointsEarned,
    balanceAfter: account.currentBalance,
    description: `Earned ${pointsEarned} loyalty points from Order #${order._id.toString().slice(-4)}`,
    metadata: {
      orderTotal: netPaidAmount,
      pointsRate,
    },
  });

  // Update order document
  order.loyaltyPointsEarned = pointsEarned;
  order.loyaltyPointsAwarded = true;
  order.loyaltyPointsAwardedAt = new Date();
  await order.save();

  // Create notification if user has not opted out
  try {
    const user = await User.findById(order.userId);
    if (user && user.notificationPreferences?.promotional !== false) {
      await Notification.create({
        restaurantId: order.restaurantId,
        userId: order.userId,
        orderId: order._id,
        title: "Loyalty Points Credited!",
        body: `You just earned ${pointsEarned} loyalty points from your order at ${restaurant.name}. Current balance: ${account.currentBalance} points.`,
        type: "points_credited",
        metadata: { points: pointsEarned, currentBalance: account.currentBalance },
      });
    }
  } catch (_) {}

  return { pointsEarned, currentBalance: account.currentBalance };
}

/**
 * Internal helper to reverse points when an order is Cancelled or Refunded.
 * Reverses both earned points (debit) and redeemed points (refund back to balance).
 */
export async function reverseLoyaltyPointsForOrder(order, reason = "Order cancelled") {
  if (!order || !order.restaurantId || !order.userId) return null;

  // 1. If order earned points, debit them back
  if (order.loyaltyPointsAwarded && order.loyaltyPointsEarned > 0) {
    const pointsToDebit = order.loyaltyPointsEarned;

    // Check if cancellation reversal was already performed
    const existingDebit = await LoyaltyLedger.findOne({
      orderId: order._id,
      transactionType: "CANCEL_REVERSAL",
    });

    if (!existingDebit) {
      // Find account first to prevent negative balance
      const account = await LoyaltyAccount.findOne({
        restaurantId: order.restaurantId,
        userId: order.userId,
      });

      if (account) {
        const actualDeduction = Math.min(account.currentBalance, pointsToDebit);
        account.currentBalance = Math.max(0, account.currentBalance - actualDeduction);
        account.totalEarned = Math.max(0, account.totalEarned - pointsToDebit);
        await account.save();

        await LoyaltyLedger.create({
          restaurantId: order.restaurantId,
          userId: order.userId,
          orderId: order._id,
          transactionType: "CANCEL_REVERSAL",
          points: -actualDeduction,
          balanceAfter: account.currentBalance,
          description: `Reversed ${actualDeduction} points due to cancelled Order #${order._id.toString().slice(-4)} (${reason})`,
          metadata: { reason, originalPointsEarned: pointsToDebit },
        });
      }

      order.loyaltyPointsAwarded = false;
      await order.save();
    }
  }

  // 2. If order REDEEMED points at checkout, refund them back to customer!
  const redeemedPoints = order.appliedLoyaltyReward?.pointsRedeemed || 0;
  if (redeemedPoints > 0) {
    const existingRefund = await LoyaltyLedger.findOne({
      orderId: order._id,
      transactionType: "REFUND_REVERSAL",
    });

    if (!existingRefund) {
      const account = await LoyaltyAccount.findOneAndUpdate(
        { restaurantId: order.restaurantId, userId: order.userId },
        {
          $inc: {
            currentBalance: redeemedPoints,
            totalRedeemed: -redeemedPoints,
          },
        },
        { new: true, upsert: true }
      );

      await LoyaltyLedger.create({
        restaurantId: order.restaurantId,
        userId: order.userId,
        orderId: order._id,
        transactionType: "REFUND_REVERSAL",
        points: redeemedPoints,
        balanceAfter: account.currentBalance,
        description: `Refunded ${redeemedPoints} redeemed points back to balance for cancelled Order #${order._id.toString().slice(-4)}`,
        metadata: { reason, redeemedPoints },
      });
    }
  }
}

/**
 * GET /restaurant/admin/loyalty
 * Admin endpoint: Get current loyalty configuration & overview statistics.
 */
export async function getAdminLoyaltyConfigController(req, res) {
  try {
    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const config = restaurant.loyaltyProgram || {
      isEnabled: true,
      pointsPerRupee: 0.1,
      minimumOrderValueForEarn: 50,
      canEarnOnDiscountedOrders: false,
      rewards: [],
    };

    // Loyalty circulation metrics
    const stats = await LoyaltyAccount.aggregate([
      { $match: { restaurantId: req.restaurantId } },
      {
        $group: {
          _id: null,
          totalMembers: { $sum: 1 },
          totalPointsInCirculation: { $sum: "$currentBalance" },
          totalPointsEarned: { $sum: "$totalEarned" },
          totalPointsRedeemed: { $sum: "$totalRedeemed" },
        },
      },
    ]);

    const overview = stats[0] || {
      totalMembers: 0,
      totalPointsInCirculation: 0,
      totalPointsEarned: 0,
      totalPointsRedeemed: 0,
    };

    res.json({
      config,
      stats: overview,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * PUT /restaurant/admin/loyalty
 * Admin endpoint: Update loyalty configuration & reward catalog.
 */
export async function updateAdminLoyaltyConfigController(req, res) {
  try {
    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const {
      isEnabled,
      pointsPerRupee,
      minimumOrderValueForEarn,
      canEarnOnDiscountedOrders,
      rewards,
    } = req.body;

    if (!restaurant.loyaltyProgram) {
      restaurant.loyaltyProgram = {};
    }

    if (isEnabled !== undefined) restaurant.loyaltyProgram.isEnabled = Boolean(isEnabled);
    if (pointsPerRupee !== undefined) {
      const rate = Number(pointsPerRupee);
      if (isNaN(rate) || rate < 0) return res.status(400).json({ error: "Invalid points per rupee" });
      restaurant.loyaltyProgram.pointsPerRupee = rate;
    }
    if (minimumOrderValueForEarn !== undefined) {
      restaurant.loyaltyProgram.minimumOrderValueForEarn = Math.max(0, Number(minimumOrderValueForEarn) || 0);
    }
    if (canEarnOnDiscountedOrders !== undefined) {
      restaurant.loyaltyProgram.canEarnOnDiscountedOrders = Boolean(canEarnOnDiscountedOrders);
    }

    if (Array.isArray(rewards)) {
      restaurant.loyaltyProgram.rewards = rewards.map((r, index) => ({
        rewardId: r.rewardId || `rew_${Date.now()}_${index}`,
        title: (r.title || "Reward").trim(),
        description: (r.description || "").trim(),
        pointsRequired: Math.max(1, Number(r.pointsRequired) || 100),
        discountType: r.discountType === "percentage" ? "percentage" : "flat",
        discountValue: Math.max(1, Number(r.discountValue) || 10),
        maxDiscountAmount: r.maxDiscountAmount ? Number(r.maxDiscountAmount) : null,
        minOrderValue: Math.max(0, Number(r.minOrderValue) || 0),
        isActive: r.isActive !== false,
      }));
    }

    await restaurant.save();
    res.json({
      message: "Loyalty program settings updated successfully",
      config: restaurant.loyaltyProgram,
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * GET /restaurant/admin/loyalty/ledger
 * Admin endpoint: Auditable ledger transactions.
 */
export async function getAdminLoyaltyLedgerController(req, res) {
  try {
    const limit = Math.min(100, Math.max(10, Number(req.query.limit) || 50));
    const ledger = await LoyaltyLedger.find({ restaurantId: req.restaurantId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .populate("userId", "fullName email phoneNumber")
      .lean();

    res.json({ ledger });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}
