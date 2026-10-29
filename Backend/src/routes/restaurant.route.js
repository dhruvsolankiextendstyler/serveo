import express from "express";
import multer from "multer";
import {
  adminCheck,
  requireRoles,
  requireActiveSubscription,
} from "../middlewares/adminCheck.js";
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
