import { Coupon } from "../models/coupon.models.js";
import { Order } from "../models/order.models.js";
import { Restaurant } from "../models/restaurant.models.js";
import { Item } from "../models/item.models.js";
import mongoose from "mongoose";

/**
 * Pure calculation & validation function for coupons.
 * Used by both customer preview API and order creation logic.
 */
export async function validateAndCalculateCouponDiscount({
  couponCode,
  restaurantId,
  userId,
  orderItems = [],
  subtotal = 0,
}) {
  if (!couponCode || typeof couponCode !== "string") {
    return { isValid: false, message: "Coupon code is required" };
  }

  const normalizedCode = couponCode.trim().toUpperCase();

  const query = {
    code: normalizedCode,
  };
  if (restaurantId) {
    query.$or = [
      { restaurantId: restaurantId },
      { restaurantId: { $exists: false } },
      { restaurantId: null },
    ];
  }

  const coupon = await Coupon.findOne(query);
  if (!coupon) {
    return { isValid: false, message: `Coupon code '${normalizedCode}' is invalid.` };
  }

  // Tenant check
  if (restaurantId && coupon.restaurantId && coupon.restaurantId.toString() !== restaurantId.toString()) {
    return { isValid: false, message: "Coupon is not valid for this restaurant." };
  }

  // Active status check
  if (!coupon.isActive) {
    return { isValid: false, message: "This coupon is currently inactive." };
  }

  // Date range check
  const now = new Date();
  if (coupon.startDate && new Date(coupon.startDate) > now) {
    return { isValid: false, message: "This coupon promotion has not started yet." };
  }
  if (coupon.endDate && new Date(coupon.endDate) < now) {
    return { isValid: false, message: "This coupon has expired." };
  }

  // Total usage limit check
  if (coupon.totalUsageLimit !== null && coupon.totalUsageLimit !== undefined) {
    if (coupon.usedCount >= coupon.totalUsageLimit) {
      return { isValid: false, message: "This coupon has reached its maximum total usage limit." };
    }
  }

  // Per-customer usage limit check
  if (userId) {
    const userUsageCount = await Order.countDocuments({
      userId: userId,
      status: { $nin: ["Cancelled", "Payment Rejected"] },
      "appliedCoupon.code": normalizedCode,
      ...(restaurantId ? { restaurantId: restaurantId } : {}),
    });

    const perCustomerLimit = coupon.perCustomerLimit || 1;
    if (userUsageCount >= perCustomerLimit) {
      return {
        isValid: false,
        message: `You have already redeemed this coupon the maximum allowed number of times (${perCustomerLimit}).`,
      };
    }
  }

  // First-order coupon check
  if (coupon.discountType === "first_order" && userId) {
    const previousOrdersCount = await Order.countDocuments({
      userId: userId,
      status: { $nin: ["Cancelled", "Payment Rejected"] },
      ...(restaurantId ? { restaurantId: restaurantId } : {}),
    });
    if (previousOrdersCount > 0) {
      return { isValid: false, message: "This coupon is valid only on your very first order." };
    }
  }

  // Item / Category restrictions check
  let eligibleSubtotal = 0;
  const hasCategoryRestriction = Array.isArray(coupon.restrictedCategories) && coupon.restrictedCategories.length > 0;
  const hasItemRestriction = Array.isArray(coupon.restrictedItems) && coupon.restrictedItems.length > 0;

  if (hasCategoryRestriction || hasItemRestriction) {
    for (const item of orderItems) {
      let isItemEligible = true;

      if (hasItemRestriction) {
        const itemIdStr = (item.itemId || item._id || "").toString();
        isItemEligible = coupon.restrictedItems.some((ri) => ri.toString() === itemIdStr);
      }

      if (isItemEligible && hasCategoryRestriction && item.category) {
        isItemEligible = coupon.restrictedCategories.some(
          (rc) => rc.toLowerCase() === item.category.toLowerCase()
        );
      }

      if (isItemEligible) {
        const itemUnitCost = Number(item.itemPrice || 0);
        let customTotal = 0;
        if (Array.isArray(item.selectedCustomizations)) {
          customTotal = item.selectedCustomizations.reduce((sum, c) => sum + (Number(c.price) || 0), 0);
        }
        eligibleSubtotal += (itemUnitCost + customTotal) * (Number(item.quantity) || 1);
      }
    }

    if (eligibleSubtotal <= 0) {
      return {
        isValid: false,
        message: "None of the items in your tray are eligible for this coupon discount.",
      };
    }
  } else {
    eligibleSubtotal = subtotal;
  }

  // Minimum Order Value check (against eligible subtotal)
  if (coupon.minOrderValue > 0 && eligibleSubtotal < coupon.minOrderValue) {
    return {
      isValid: false,
      message: `Minimum order value of ₹${coupon.minOrderValue} is required to apply this coupon. Eligible items subtotal: ₹${eligibleSubtotal}.`,
    };
  }

  // Calculate discount amount
  let discountAmount = 0;
  if (coupon.discountType === "percentage" || coupon.discountType === "first_order") {
    const rawDiscount = (eligibleSubtotal * coupon.discountValue) / 100;
    if (coupon.maxDiscountAmount && coupon.maxDiscountAmount > 0) {
      discountAmount = Math.min(coupon.maxDiscountAmount, rawDiscount);
    } else {
      discountAmount = rawDiscount;
    }
  } else if (coupon.discountType === "fixed" || coupon.discountType === "free_delivery") {
    discountAmount = Math.min(eligibleSubtotal, coupon.discountValue);
  }

  discountAmount = Math.round(discountAmount * 100) / 100;

  return {
    isValid: true,
    coupon: {
      _id: coupon._id,
      code: coupon.code,
      description: coupon.description,
      discountType: coupon.discountType,
      discountValue: coupon.discountValue,
      maxDiscountAmount: coupon.maxDiscountAmount,
      minOrderValue: coupon.minOrderValue,
    },
    eligibleSubtotal,
    discountAmount,
    newTotal: Math.max(0, subtotal - discountAmount),
    message: `Coupon '${coupon.code}' applied successfully! Saved ₹${discountAmount}.`,
  };
}

/**
 * POST /order/coupon/validate
 * Customer endpoint: validates coupon code for the active tray.
 */
export async function validateCouponController(req, res) {
  try {
    const { couponCode, restaurantId, orderItems, subtotal } = req.body;
    const userId = req.user?.uid ? (req.user._id || req.user.mongoId) : null;

    let targetUserId = userId;
    if (!targetUserId && req.user?.uid) {
      // Find User Mongo ID if req.user has firebase uid
      const { User } = await import("../models/user.models.js");
      const userDoc = await User.findOne({ uid: req.user.uid });
      if (userDoc) targetUserId = userDoc._id;
    }

    const result = await validateAndCalculateCouponDiscount({
      couponCode,
      restaurantId,
      userId: targetUserId,
      orderItems: orderItems || [],
      subtotal: Number(subtotal) || 0,
    });

    if (!result.isValid) {
      return res.status(400).json({
        isValid: false,
        error: result.message,
        message: result.message,
      });
    }

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * GET /restaurant/admin/coupons
 * Admin endpoint: List all coupons for authorized restaurant.
 */
export async function getAdminCouponsController(req, res) {
  try {
    const restaurantId = req.restaurantId;
    const coupons = await Coupon.find({ restaurantId }).sort({ createdAt: -1 });

    // Attach real-time order attribution summary for each coupon
    const couponCodes = coupons.map((c) => c.code);
    const usageAgg = await Order.aggregate([
      {
        $match: {
          restaurantId: req.restaurantId,
          "appliedCoupon.code": { $in: couponCodes },
          status: { $nin: ["Cancelled", "Payment Rejected"] },
        },
      },
      {
        $group: {
          _id: "$appliedCoupon.code",
          realUsageCount: { $sum: 1 },
          totalDiscountGiven: { $sum: "$appliedCoupon.discountAmount" },
          attributedNetSales: { $sum: "$totalAmount" },
        },
      },
    ]);

    const statsMap = {};
    usageAgg.forEach((u) => {
      statsMap[u._id] = u;
    });

    const enrichedCoupons = coupons.map((c) => {
      const stats = statsMap[c.code] || {
        realUsageCount: c.usedCount,
        totalDiscountGiven: 0,
        attributedNetSales: 0,
      };
      return {
        ...c.toObject(),
        realUsageCount: Math.max(c.usedCount, stats.realUsageCount || 0),
        totalDiscountGiven: stats.totalDiscountGiven || 0,
        attributedNetSales: stats.attributedNetSales || 0,
      };
    });

    res.json({ coupons: enrichedCoupons });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * POST /restaurant/admin/coupons
 * Admin endpoint: Create a new coupon.
 */
export async function createCouponController(req, res) {
  try {
    const restaurantId = req.restaurantId;
    const {
      code,
      description,
      discountType,
      discountValue,
      maxDiscountAmount,
      minOrderValue,
      startDate,
      endDate,
      totalUsageLimit,
      perCustomerLimit,
      restrictedCategories,
      restrictedItems,
    } = req.body;

    if (!code || typeof code !== "string" || !code.trim()) {
      return res.status(400).json({ error: "Coupon code is required" });
    }

    const normalizedCode = code.trim().toUpperCase();

    // Check duplicate code in this restaurant
    const existing = await Coupon.findOne({ restaurantId, code: normalizedCode });
    if (existing) {
      return res.status(400).json({ error: `Coupon '${normalizedCode}' already exists for this restaurant` });
    }

    if (discountValue === undefined || isNaN(Number(discountValue)) || Number(discountValue) <= 0) {
      return res.status(400).json({ error: "A positive discount value is required" });
    }

    if (discountType === "percentage" && Number(discountValue) > 100) {
      return res.status(400).json({ error: "Percentage discount cannot exceed 100%" });
    }

    const coupon = new Coupon({
      restaurantId,
      code: normalizedCode,
      description: (description || "").trim(),
      discountType: discountType || "percentage",
      discountValue: Number(discountValue),
      maxDiscountAmount: maxDiscountAmount !== null && maxDiscountAmount !== undefined ? Number(maxDiscountAmount) : null,
      minOrderValue: Number(minOrderValue) || 0,
      startDate: startDate ? new Date(startDate) : new Date(),
      endDate: endDate ? new Date(endDate) : null,
      totalUsageLimit: totalUsageLimit ? Number(totalUsageLimit) : null,
      perCustomerLimit: Number(perCustomerLimit) || 1,
      restrictedCategories: Array.isArray(restrictedCategories) ? restrictedCategories : [],
      restrictedItems: Array.isArray(restrictedItems) ? restrictedItems : [],
      createdBy: req.user?.email || "owner",
    });

    await coupon.save();
    res.status(201).json({ message: "Coupon created successfully", coupon });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * PUT /restaurant/admin/coupons/:id
 * Admin endpoint: Update an existing coupon.
 */
export async function updateCouponController(req, res) {
  try {
    const { id } = req.params;
    const coupon = await Coupon.findOne({ _id: id, restaurantId: req.restaurantId });
    if (!coupon) {
      return res.status(404).json({ error: "Coupon not found" });
    }

    const {
      description,
      discountType,
      discountValue,
      maxDiscountAmount,
      minOrderValue,
      startDate,
      endDate,
      isActive,
      totalUsageLimit,
      perCustomerLimit,
      restrictedCategories,
      restrictedItems,
    } = req.body;

    if (description !== undefined) coupon.description = description.trim();
    if (discountType !== undefined) coupon.discountType = discountType;
    if (discountValue !== undefined) {
      const val = Number(discountValue);
      if (val <= 0 || (coupon.discountType === "percentage" && val > 100)) {
        return res.status(400).json({ error: "Invalid discount value" });
      }
      coupon.discountValue = val;
    }
    if (maxDiscountAmount !== undefined) coupon.maxDiscountAmount = maxDiscountAmount ? Number(maxDiscountAmount) : null;
    if (minOrderValue !== undefined) coupon.minOrderValue = Number(minOrderValue) || 0;
    if (startDate !== undefined) coupon.startDate = new Date(startDate);
    if (endDate !== undefined) coupon.endDate = endDate ? new Date(endDate) : null;
    if (isActive !== undefined) coupon.isActive = Boolean(isActive);
    if (totalUsageLimit !== undefined) coupon.totalUsageLimit = totalUsageLimit ? Number(totalUsageLimit) : null;
    if (perCustomerLimit !== undefined) coupon.perCustomerLimit = Number(perCustomerLimit) || 1;
    if (restrictedCategories !== undefined) coupon.restrictedCategories = restrictedCategories;
    if (restrictedItems !== undefined) coupon.restrictedItems = restrictedItems;

    await coupon.save();
    res.json({ message: "Coupon updated successfully", coupon });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * PATCH /restaurant/admin/coupons/:id/status
 * Admin endpoint: Toggle active status.
 */
export async function toggleCouponStatusController(req, res) {
  try {
    const { id } = req.params;
    const coupon = await Coupon.findOne({ _id: id, restaurantId: req.restaurantId });
    if (!coupon) {
      return res.status(404).json({ error: "Coupon not found" });
    }

    coupon.isActive = req.body.isActive !== undefined ? Boolean(req.body.isActive) : !coupon.isActive;
    await coupon.save();
    res.json({ message: `Coupon is now ${coupon.isActive ? "Active" : "Inactive"}`, coupon });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * DELETE /restaurant/admin/coupons/:id
 * Admin endpoint: Delete a coupon.
 */
export async function deleteCouponController(req, res) {
  try {
    const { id } = req.params;
    const coupon = await Coupon.findOneAndDelete({ _id: id, restaurantId: req.restaurantId });
    if (!coupon) {
      return res.status(404).json({ error: "Coupon not found" });
    }
    res.json({ message: "Coupon deleted successfully", couponId: id });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}
