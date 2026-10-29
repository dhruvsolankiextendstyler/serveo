import express from "express";
import multer from "multer";
import { adminCheck } from "../middlewares/adminCheck.js";
import {
  getPublicRestaurantInfoController,
  getPublicRestaurantMenuController,
  getAdminRestaurantSettingsController,
  updateAdminRestaurantSettingsController,
  updatePauseStatusController,
  uploadRestaurantLogoController,
  generateRestaurantQrController,
} from "../controllers/restaurant.controller.js";
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

// 🔹 ADMIN-SCOPED CONFIGURATION (Strictly authenticated & scoped)
restaurantRoute.get("/admin/settings", adminCheck, getAdminRestaurantSettingsController);
restaurantRoute.put("/admin/settings", adminCheck, updateAdminRestaurantSettingsController);
restaurantRoute.patch("/admin/settings", adminCheck, updateAdminRestaurantSettingsController);
restaurantRoute.patch("/admin/pause-status", adminCheck, updatePauseStatusController);
restaurantRoute.post("/admin/upload-logo", adminCheck, uploadMiddleware, uploadRestaurantLogoController);
restaurantRoute.get("/admin/qr", adminCheck, generateRestaurantQrController);

