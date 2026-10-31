import { admin } from "../utils/firebase_app.js";
import { Restaurant } from "../models/restaurant.models.js";
import { getPlanConfig } from "../models/plan.models.js";
import { logger } from "../utils/logger.js";

/**
 * Middleware: Verifies Firebase ID Token, checks staff membership and roles,
 * and attaches the user's authorized restaurant and RBAC role to req.
 *
 * Supported Roles:
 * - "owner": Full access (settings, staff, subscription, menu, orders, payments, reports)
 * - "manager": Operations (orders, menu, reports, kitchen)
 * - "kitchen": Kitchen display & order status transitions
 * - "cashier": Order details, payment verification & counter collection
 * - "viewer": Read-only access to live orders and reports
 */
export const adminCheck = async (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) {
    return res.status(401).json({ message: "Access denied No token" });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    const email = decodedToken.email ? decodedToken.email.toLowerCase().trim() : null;
    const uid = decodedToken.uid;

    let restaurant = null;

    // 1. Search by staff membership
    if (email) {
      restaurant = await Restaurant.findOne({ "staff.email": email, "staff.isActive": true });
    }
    if (!restaurant && uid) {
      restaurant = await Restaurant.findOne({ "staff.uid": uid, "staff.isActive": true });
    }

    // 2. Search by legacy admin email/uid arrays
    if (!restaurant && email) {
      restaurant = await Restaurant.findOne({ adminEmails: email });
    }
    if (!restaurant && uid) {
      restaurant = await Restaurant.findOne({ adminUids: uid });
    }

    // 3. Backward compatibility for legacy fixed admin email
    if (!restaurant && email === "admin123@ad.in") {
      restaurant = (await Restaurant.findOne({ slug: "default" })) || (await Restaurant.findOne({}));
    }

    if (!restaurant) {
      logger.warn("auth", "Unauthorized admin access attempt", {
        email,
        uid,
        path: req.originalUrl,
      });
      return res.status(401).json({
        message: "Unauthorized access",
        error: "You are not an authorized staff member for any restaurant.",
      });
    }

    // 4. Resolve Role
    let resolvedRole = "viewer";
    let matchedStaff = null;

    if (Array.isArray(restaurant.staff)) {
      matchedStaff = restaurant.staff.find(
        (s) =>
          s.isActive &&
          ((uid && s.uid === uid) || (email && s.email && s.email.toLowerCase() === email))
      );
      if (matchedStaff) {
        resolvedRole = matchedStaff.role;
      }
    }

    // Owners: Explicit list or legacy admin
    if (
      (email && restaurant.adminEmails?.map((e) => e.toLowerCase()).includes(email)) ||
      (uid && restaurant.adminUids?.includes(uid)) ||
      email === "admin123@ad.in"
    ) {
      resolvedRole = "owner";
    }

    req.user = decodedToken;
    req.restaurant = restaurant;
    req.restaurantId = restaurant._id;
    req.staffRole = resolvedRole;
    req.isOwner = resolvedRole === "owner";
    req.staffMember = matchedStaff;

    next();
  } catch (error) {
    logger.error("auth", "Token verification failure", error, {
      path: req.originalUrl,
    });
    res.status(401).json({ message: "Invalid or expired token", error: error.message });
  }
};

/**
 * Middleware: Restricts access to specified roles.
 * Must be placed AFTER adminCheck.
 */
export const requireRoles = (allowedRoles = []) => {
  return (req, res, next) => {
    if (!req.staffRole) {
      return res.status(401).json({ error: "UNAUTHORIZED", message: "Authentication required" });
    }

    if (!allowedRoles.includes(req.staffRole)) {
      logger.warn("auth", "Forbidden role action attempt", {
        actorEmail: req.user?.email,
        staffRole: req.staffRole,
        requiredRoles: allowedRoles,
        path: req.originalUrl,
        restaurantId: req.restaurantId,
      });
      return res.status(403).json({
        error: "FORBIDDEN_ROLE",
        message: `Action requires one of the following roles: [${allowedRoles.join(
          ", "
        )}]. Current role: '${req.staffRole}'.`,
      });
    }

    next();
  };
};

/**
 * Middleware: Enforces active subscription status for mutating operations.
 * Allows read operations on orders even if subscription has expired.
 */
export const requireActiveSubscription = (req, res, next) => {
  const restaurant = req.restaurant;
  if (!restaurant || !restaurant.subscription) {
    return next();
  }

  const sub = restaurant.subscription;
  if (sub.adminOverride === true) {
    return next(); // Administrative override bypasses expiration
  }

  if (sub.status === "expired" || sub.status === "canceled") {
    // Check if grace period is active
    if (sub.endDate) {
      const graceMs = (sub.gracePeriodDays || 7) * 24 * 60 * 60 * 1000;
      const expiredAt = new Date(sub.endDate).getTime();
      if (Date.now() > expiredAt + graceMs) {
        return res.status(403).json({
          error: "SUBSCRIPTION_EXPIRED",
          message:
            "Your subscription has expired and the grace period has ended. Please renew to continue operational changes.",
        });
      }
    }
  }

  next();
};

/**
 * Middleware: Checks feature entitlements based on subscription plan.
 */
export const requirePlanFeature = (featureKey) => {
  return (req, res, next) => {
    const restaurant = req.restaurant;
    if (restaurant?.subscription?.adminOverride === true) {
      return next();
    }
    const planId = restaurant?.subscription?.planId || "starter";
    const plan = getPlanConfig(planId);

    if (!plan.features[featureKey]) {
      return res.status(403).json({
        error: "FEATURE_NOT_IN_PLAN",
        message: `The feature '${featureKey}' is not included in your ${plan.name} plan. Please upgrade to unlock.`,
        planId,
        featureKey,
      });
    }

    next();
  };
};
