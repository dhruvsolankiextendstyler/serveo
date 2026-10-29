import { Restaurant } from "../models/restaurant.models.js";
import { AuditLog } from "../models/audit_log.models.js";
import { getPlanConfig } from "../models/plan.models.js";
import { logger } from "../utils/logger.js";

/**
 * 1. GET /restaurant/admin/staff
 * Lists all staff members for the authenticated administrator's restaurant.
 */
export async function getStaffController(req, res) {
  try {
    const restaurant = req.restaurant;
    const staffList = (restaurant.staff || []).map((s) => ({
      id: s._id,
      uid: s.uid,
      email: s.email,
      name: s.name,
      role: s.role,
      invitedBy: s.invitedBy,
      addedAt: s.addedAt,
      isActive: s.isActive,
    }));

    res.json({
      restaurantId: restaurant._id,
      staff: staffList,
      totalCount: staffList.length,
      currentRole: req.staffRole,
      isOwner: req.isOwner,
    });
  } catch (error) {
    logger.error("admin", "Get Staff Error", error, { restaurantId: req.restaurantId });
    res.status(500).json({ error: error.message });
  }
}

/**
 * 2. POST /restaurant/admin/staff
 * Adds a new staff member to the restaurant.
 * Restricted to role: "owner". Enforces subscription plan staff limit.
 */
export async function addStaffController(req, res) {
  try {
    const { email, name, role = "manager" } = req.body;

    if (!email || !email.includes("@")) {
      return res.status(400).json({ error: "A valid staff email address is required" });
    }

    const validRoles = ["owner", "manager", "kitchen", "cashier", "viewer"];
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        error: `Invalid role '${role}'. Valid roles: ${validRoles.join(", ")}`,
      });
    }

    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // 1. Subscription Plan Limit Enforcement
    const planConfig = getPlanConfig(restaurant.subscription?.planId);
    const maxStaff =
      restaurant.subscription?.customLimits?.maxStaffAccounts ?? planConfig.maxStaffAccounts;

    const currentActiveStaffCount = (restaurant.staff || []).filter((s) => s.isActive).length;
    if (currentActiveStaffCount >= maxStaff) {
      return res.status(403).json({
        error: "PLAN_LIMIT_REACHED",
        limitType: "maxStaffAccounts",
        message: `Staff limit reached for your ${planConfig.name} plan (${currentActiveStaffCount}/${maxStaff}). Please upgrade your plan to add more staff.`,
        current: currentActiveStaffCount,
        max: maxStaff,
      });
    }

    // 2. Check for duplicate staff
    const existingIndex = (restaurant.staff || []).findIndex(
      (s) => s.email.toLowerCase() === normalizedEmail
    );

    if (existingIndex !== -1) {
      const existing = restaurant.staff[existingIndex];
      if (existing.isActive) {
        return res.status(400).json({
          error: "Staff member with this email already exists in this restaurant",
        });
      }
      // Reactivate existing inactive staff member
      existing.isActive = true;
      existing.role = role;
      if (name) existing.name = name.trim();
      existing.addedAt = new Date();
      existing.invitedBy = req.user?.email || "owner";
    } else {
      restaurant.staff.push({
        uid: "",
        email: normalizedEmail,
        name: (name || "").trim() || normalizedEmail.split("@")[0],
        role,
        invitedBy: req.user?.email || "owner",
        addedAt: new Date(),
        isActive: true,
      });
    }

    await restaurant.save();

    // 3. Audit Log & Structured Logging
    await AuditLog.create({
      restaurantId: restaurant._id,
      actorUid: req.user?.uid || "unknown",
      actorEmail: req.user?.email || "unknown",
      actorRole: req.staffRole,
      action: "STAFF_ADDED",
      target: normalizedEmail,
      details: { role, name },
    });

    logger.audit(restaurant._id, req.user, "STAFF_ADDED", normalizedEmail, { role, name });

    const newStaff = restaurant.staff.find((s) => s.email.toLowerCase() === normalizedEmail);

    res.status(201).json({
      message: "Staff member added successfully",
      staffMember: newStaff,
    });
  } catch (error) {
    logger.error("admin", "Add Staff Error", error, { restaurantId: req.restaurantId });
    res.status(500).json({ error: error.message });
  }
}

/**
 * 3. PATCH /restaurant/admin/staff/:staffId/role
 * Updates a staff member's role or status.
 * Restricted to role: "owner". Enforces last-owner protection.
 */
export async function updateStaffRoleController(req, res) {
  try {
    const { staffId } = req.params;
    const { role, name, isActive } = req.body;

    const validRoles = ["owner", "manager", "kitchen", "cashier", "viewer"];
    if (role && !validRoles.includes(role)) {
      return res.status(400).json({
        error: `Invalid role '${role}'. Valid roles: ${validRoles.join(", ")}`,
      });
    }

    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const staffMember = restaurant.staff.id(staffId);
    if (!staffMember) {
      return res.status(404).json({ error: "Staff member not found" });
    }

    const oldRole = staffMember.role;

    // Last-Owner Protection Guard:
    // If the target member is currently an "owner" and is being demoted or deactivated:
    const isDemotingOwner = oldRole === "owner" && role && role !== "owner";
    const isDeactivatingOwner = oldRole === "owner" && isActive === false;

    if (isDemotingOwner || isDeactivatingOwner) {
      const activeOwnersCount = restaurant.staff.filter(
        (s) => s.isActive && s.role === "owner"
      ).length;

      if (activeOwnersCount <= 1) {
        return res.status(400).json({
          error: "CANNOT_REMOVE_LAST_OWNER",
          message:
            "Cannot remove or demote the last authorized owner of this restaurant. Assign another owner before demoting this account.",
        });
      }
    }

    if (role) staffMember.role = role;
    if (name !== undefined) staffMember.name = name.trim();
    if (isActive !== undefined) staffMember.isActive = Boolean(isActive);

    await restaurant.save();

    await AuditLog.create({
      restaurantId: restaurant._id,
      actorUid: req.user?.uid || "unknown",
      actorEmail: req.user?.email || "unknown",
      actorRole: req.staffRole,
      action: "STAFF_ROLE_UPDATED",
      target: staffMember.email,
      details: { fromRole: oldRole, toRole: staffMember.role, isActive: staffMember.isActive },
    });

    logger.audit(restaurant._id, req.user, "STAFF_ROLE_UPDATED", staffMember.email, {
      fromRole: oldRole,
      toRole: staffMember.role,
    });

    res.json({
      message: "Staff member updated successfully",
      staffMember,
    });
  } catch (error) {
    logger.error("admin", "Update Staff Role Error", error, { restaurantId: req.restaurantId });
    res.status(500).json({ error: error.message });
  }
}

/**
 * 4. DELETE /restaurant/admin/staff/:staffId
 * Removes or deactivates a staff member.
 * Restricted to role: "owner". Enforces last-owner protection.
 */
export async function removeStaffController(req, res) {
  try {
    const { staffId } = req.params;

    const restaurant = await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const staffMember = restaurant.staff.id(staffId);
    if (!staffMember) {
      return res.status(404).json({ error: "Staff member not found" });
    }

    // Last-Owner Protection Guard
    if (staffMember.role === "owner" && staffMember.isActive) {
      const activeOwnersCount = restaurant.staff.filter(
        (s) => s.isActive && s.role === "owner"
      ).length;

      if (activeOwnersCount <= 1) {
        return res.status(400).json({
          error: "CANNOT_REMOVE_LAST_OWNER",
          message:
            "Cannot remove the last owner of the restaurant. Please transfer ownership or assign another owner first.",
        });
      }
    }

    const targetEmail = staffMember.email;

    // Safely deactivate staff member to maintain audit trail
    staffMember.isActive = false;
    await restaurant.save();

    await AuditLog.create({
      restaurantId: restaurant._id,
      actorUid: req.user?.uid || "unknown",
      actorEmail: req.user?.email || "unknown",
      actorRole: req.staffRole,
      action: "STAFF_REMOVED",
      target: targetEmail,
      details: { role: staffMember.role },
    });

    logger.audit(restaurant._id, req.user, "STAFF_REMOVED", targetEmail, {
      role: staffMember.role,
    });

    res.json({
      message: `Staff member '${targetEmail}' removed successfully.`,
      staffId,
    });
  } catch (error) {
    logger.error("admin", "Remove Staff Error", error, { restaurantId: req.restaurantId });
    res.status(500).json({ error: error.message });
  }
}

/**
 * 5. GET /restaurant/admin/audit-logs
 * Retrieves audit logs for the restaurant.
 * Restricted to role: "owner".
 */
export async function getAuditLogsController(req, res) {
  try {
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 50));
    const logs = await AuditLog.find({ restaurantId: req.restaurantId })
      .sort({ timestamp: -1 })
      .limit(limit)
      .lean();

    res.json({
      restaurantId: req.restaurantId,
      logs,
      count: logs.length,
    });
  } catch (error) {
    logger.error("admin", "Get Audit Logs Error", error, { restaurantId: req.restaurantId });
    res.status(500).json({ error: error.message });
  }
}

