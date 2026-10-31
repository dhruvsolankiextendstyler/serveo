import express from "express";
import multer from "multer";
import {
  adminCheck,
  requireRoles,
  requireActiveSubscription,
  requirePlanFeature,
} from "../middlewares/adminCheck.js";
import { authCheck } from "../middlewares/authCheck.js";
import {
  getPublicRestaurantInfoController,
  getPublicRestaurantMenuController,
  getAdminRestaurantSettingsController,
  updateAdminRestaurantSettingsController,
  updatePauseStatusController,
  uploadRestaurantLogoController,
  generateRestaurantQrController,
} from "../controllers/restaurant.controller.js";
import {
  getStaffController,
  addStaffController,
  updateStaffRoleController,
  removeStaffController,
  getAuditLogsController,
} from "../controllers/staff.controller.js";
import {
  getSubscriptionStatusController,
  assignPlanController,
} from "../controllers/subscription.controller.js";
import {
  getAdminCouponsController,
  createCouponController,
  updateCouponController,
  toggleCouponStatusController,
  deleteCouponController,
} from "../controllers/coupon.controller.js";
import {
  getActiveCampaignsController,
  recordCampaignClickController,
  getAdminCampaignsController,
  createCampaignController,
  updateCampaignController,
  toggleCampaignStatusController,
  deleteCampaignController,
} from "../controllers/campaign.controller.js";
import {
  getCustomerLoyaltyController,
  getAdminLoyaltyConfigController,
  updateAdminLoyaltyConfigController,
  getAdminLoyaltyLedgerController,
} from "../controllers/loyalty.controller.js";
import {
  getAdminReferralsController,
  updateAdminReferralsController,
} from "../controllers/referral.controller.js";
import { MAX_IMAGE_SIZE } from "../utils/image_storage.js";

export const restaurantRoute = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_IMAGE_SIZE,
  },
});

const uploadMiddleware = (req, res, next) => {
  upload.single("image")(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      if (err.code === "LIMIT_FILE_SIZE") {
        return res
          .status(400)
          .json({ error: "File exceeds 5MB limit. Please upload a smaller logo." });
      }
      return res.status(400).json({ error: err.message });
    } else if (err) {
      return res.status(400).json({ error: err.message });
    }
    next();
  });
};

// 🔹 PUBLIC ENDPOINTS (Read-only, no auth needed)
restaurantRoute.get("/public/info", getPublicRestaurantInfoController);
restaurantRoute.get("/public/info/:identifier", getPublicRestaurantInfoController);
restaurantRoute.get("/public/:identifier/menu", getPublicRestaurantMenuController);
restaurantRoute.get("/qr/:identifier", generateRestaurantQrController);

// 🔹 ADMIN-SCOPED CONFIGURATION & BUSINESS PROFILE (Owner only)
restaurantRoute.get("/admin/settings", adminCheck, requireRoles(["owner", "manager"]), getAdminRestaurantSettingsController);
restaurantRoute.put("/admin/settings", adminCheck, requireRoles(["owner"]), updateAdminRestaurantSettingsController);
restaurantRoute.patch("/admin/settings", adminCheck, requireRoles(["owner"]), updateAdminRestaurantSettingsController);
restaurantRoute.post("/admin/upload-logo", adminCheck, requireRoles(["owner"]), uploadMiddleware, uploadRestaurantLogoController);
restaurantRoute.get("/admin/qr", adminCheck, requireRoles(["owner", "manager"]), generateRestaurantQrController);

// 🔹 OPERATIONAL CONTROLS: Emergency Pause (Owner & Manager)
restaurantRoute.patch("/admin/pause-status", adminCheck, requireRoles(["owner", "manager"]), updatePauseStatusController);

// 🔹 STAFF MANAGEMENT & RBAC (Owner only)
restaurantRoute.get("/admin/staff", adminCheck, requireRoles(["owner", "manager"]), getStaffController);
restaurantRoute.post("/admin/staff", adminCheck, requireRoles(["owner"]), requireActiveSubscription, addStaffController);
restaurantRoute.patch("/admin/staff/:staffId/role", adminCheck, requireRoles(["owner"]), updateStaffRoleController);
restaurantRoute.delete("/admin/staff/:staffId", adminCheck, requireRoles(["owner"]), removeStaffController);

// 🔹 SUBSCRIPTION & USAGE LIMITS
restaurantRoute.get("/admin/subscription", adminCheck, requireRoles(["owner", "manager"]), getSubscriptionStatusController);
restaurantRoute.post("/admin/subscription/assign", adminCheck, requireRoles(["owner"]), assignPlanController);

// 🔹 AUDIT LOGS (Owner only)
restaurantRoute.get("/admin/audit-logs", adminCheck, requireRoles(["owner"]), getAuditLogsController);

// ==========================================
// 🔹 PHASE 6: MARKETING, COUPONS & RETENTION
// ==========================================

// 1. Coupons (Admin)
restaurantRoute.get("/admin/coupons", adminCheck, requireRoles(["owner", "manager"]), getAdminCouponsController);
restaurantRoute.post("/admin/coupons", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), createCouponController);
restaurantRoute.put("/admin/coupons/:id", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), updateCouponController);
restaurantRoute.patch("/admin/coupons/:id/status", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), toggleCouponStatusController);
restaurantRoute.delete("/admin/coupons/:id", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), deleteCouponController);

// 2. Campaigns & Promotions (Admin & Customer)
restaurantRoute.get("/:restaurantId/campaigns/active", getActiveCampaignsController);
restaurantRoute.post("/:restaurantId/campaigns/:id/click", recordCampaignClickController);
restaurantRoute.get("/admin/campaigns", adminCheck, requireRoles(["owner", "manager"]), getAdminCampaignsController);
restaurantRoute.post("/admin/campaigns", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), createCampaignController);
restaurantRoute.put("/admin/campaigns/:id", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), updateCampaignController);
restaurantRoute.patch("/admin/campaigns/:id/status", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), toggleCampaignStatusController);
restaurantRoute.delete("/admin/campaigns/:id", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), deleteCampaignController);

// 3. Loyalty Program (Customer & Admin)
restaurantRoute.get("/:restaurantId/loyalty", authCheck, getCustomerLoyaltyController);
restaurantRoute.get("/admin/loyalty", adminCheck, requireRoles(["owner", "manager"]), getAdminLoyaltyConfigController);
restaurantRoute.put("/admin/loyalty", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), updateAdminLoyaltyConfigController);
restaurantRoute.get("/admin/loyalty/ledger", adminCheck, requireRoles(["owner", "manager"]), getAdminLoyaltyLedgerController);

// 4. Referral Program (Admin)
restaurantRoute.get("/admin/referrals", adminCheck, requireRoles(["owner", "manager"]), getAdminReferralsController);
restaurantRoute.put("/admin/referrals", adminCheck, requireRoles(["owner", "manager"]), requirePlanFeature("marketingAndLoyalty"), updateAdminReferralsController);

