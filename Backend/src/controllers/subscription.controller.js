import { Restaurant } from "../models/restaurant.models.js";
import { Item } from "../models/item.models.js";
import { AuditLog } from "../models/audit_log.models.js";
import { PLANS, getPlanConfig } from "../models/plan.models.js";
import { logger } from "../utils/logger.js";

/**
 * 1. GET /restaurant/admin/subscription
 * Retrieves subscription status, current plan details, active usage metrics, and limits.
 * Accessible to roles: ["owner", "manager"].
 */
export async function getSubscriptionStatusController(req, res) {
  try {
    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const sub = restaurant.subscription || {
      planId: "starter",
      status: "active",
      startDate: restaurant.createdAt,
      endDate: null,
      gracePeriodDays: 7,
      adminOverride: false,
      history: [],
    };

    const planConfig = getPlanConfig(sub.planId);

    // Operational Usage Metrics
    const activeItemsCount = await Item.countDocuments({
      restaurantId: restaurant._id,
      isAvailable: { $ne: false },
    });

    const totalItemsCount = await Item.countDocuments({
      restaurantId: restaurant._id,
    });

    const activeStaffCount = (restaurant.staff || []).filter((s) => s.isActive).length;

    const maxItems = sub.customLimits?.maxActiveMenuItems ?? planConfig.maxActiveMenuItems;
    const maxStaff = sub.customLimits?.maxStaffAccounts ?? planConfig.maxStaffAccounts;

    // Check expiration and grace period status
    let isExpired = false;
    let inGracePeriod = false;
    if (sub.status === "expired" || (sub.endDate && new Date(sub.endDate) < new Date())) {
      isExpired = true;
      if (sub.endDate) {
        const graceEnd = new Date(
          new Date(sub.endDate).getTime() + (sub.gracePeriodDays || 7) * 24 * 60 * 60 * 1000
        );
        inGracePeriod = new Date() < graceEnd;
      }
    }

    res.json({
      restaurantId: restaurant._id,
      plan: {
        id: planConfig.id,
        name: planConfig.name,
        description: planConfig.description,
        features: planConfig.features,
      },
      subscription: {
        status: sub.status,
        startDate: sub.startDate,
        endDate: sub.endDate,
        trialEndsAt: sub.trialEndsAt,
        gracePeriodDays: sub.gracePeriodDays,
        adminOverride: sub.adminOverride,
        isExpired,
        inGracePeriod,
      },
      usage: {
        activeMenuItems: {
          current: activeItemsCount,
          max: maxItems,
          remaining: Math.max(0, maxItems - activeItemsCount),
          isLimitReached: activeItemsCount >= maxItems,
        },
        totalMenuItems: totalItemsCount,
        staffAccounts: {
          current: activeStaffCount,
          max: maxStaff,
          remaining: Math.max(0, maxStaff - activeStaffCount),
          isLimitReached: activeStaffCount >= maxStaff,
        },
      },
      history: sub.history || [],
      availablePlans: Object.values(PLANS).map((p) => ({
        id: p.id,
        name: p.name,
        description: p.description,
        maxActiveMenuItems: p.maxActiveMenuItems,
        maxStaffAccounts: p.maxStaffAccounts,
        features: p.features,
      })),
    });
  } catch (error) {
    logger.error("admin", "Get Subscription Status Error", error, {
      restaurantId: req.restaurantId,
    });
    res.status(500).json({ error: error.message });
  }
}

/**
 * 2. POST /restaurant/admin/subscription/assign
 * Administrative subscription management: Assign plans, extend duration, toggle override, or adjust trial.
 * Restricted to role: "owner" or verified administrative workflow.
 */
export async function assignPlanController(req, res) {
  try {
    const {
      planId,
      status = "active",
      durationDays,
      trialDays,
      adminOverride,
      reason = "Administrative plan update",
    } = req.body;

    if (planId && !PLANS[planId.toLowerCase()]) {
      return res.status(400).json({
        error: `Invalid planId '${planId}'. Available plans: ${Object.keys(PLANS).join(", ")}`,
      });
    }

    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const oldPlanId = restaurant.subscription?.planId || "starter";
    const newPlanId = planId ? planId.toLowerCase() : oldPlanId;

    if (!restaurant.subscription) {
      restaurant.subscription = {
        planId: newPlanId,
        status: status,
        startDate: new Date(),
        history: [],
      };
    }

    const sub = restaurant.subscription;
    sub.planId = newPlanId;
    if (status) sub.status = status;

    if (durationDays !== undefined) {
      if (durationDays === null || durationDays <= 0) {
        sub.endDate = null;
      } else {
        const baseDate = sub.endDate && new Date(sub.endDate) > new Date() ? new Date(sub.endDate) : new Date();
        sub.endDate = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);
      }
    }

    if (trialDays !== undefined) {
      if (trialDays === null || trialDays <= 0) {
        sub.trialEndsAt = null;
      } else {
        sub.trialEndsAt = new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000);
        sub.status = "trial";
      }
    }

    if (adminOverride !== undefined) {
      sub.adminOverride = Boolean(adminOverride);
    }

    const historyEntry = {
      action: "PLAN_ASSIGNED",
      fromPlan: oldPlanId,
      toPlan: newPlanId,
      actor: req.user?.email || "system_admin",
      reason: reason.trim(),
      timestamp: new Date(),
    };

    if (!Array.isArray(sub.history)) {
      sub.history = [];
    }
    sub.history.push(historyEntry);

    await restaurant.save();

    await AuditLog.create({
      restaurantId: restaurant._id,
      actorUid: req.user?.uid || "unknown",
      actorEmail: req.user?.email || "unknown",
      actorRole: req.staffRole,
      action: "SUBSCRIPTION_UPDATED",
      target: newPlanId,
      details: { fromPlan: oldPlanId, toPlan: newPlanId, status: sub.status, reason },
    });

    logger.audit(restaurant._id, req.user, "SUBSCRIPTION_UPDATED", newPlanId, {
      fromPlan: oldPlanId,
      toPlan: newPlanId,
      status: sub.status,
    });

    res.json({
      message: `Subscription successfully updated to ${newPlanId.toUpperCase()}`,
      subscription: sub,
    });
  } catch (error) {
    logger.error("admin", "Assign Plan Error", error, { restaurantId: req.restaurantId });
    res.status(500).json({ error: error.message });
  }
}

