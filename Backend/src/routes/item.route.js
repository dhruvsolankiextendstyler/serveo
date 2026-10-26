import express from "express";
import multer from "multer";
import { addItemController } from "../controllers/addItem.controller.js";
import { getItemController } from "../controllers/getItem.controller.js";
import { adminCheck } from "../middlewares/adminCheck.js";
import { Item } from "../models/item.models.js";
import {
  storeImageInGridFS,
  getImageFromGridFS,
  deleteImageFromGridFS,
  forceDeleteGridFSFile,
  MAX_IMAGE_SIZE,
} from "../utils/image_storage.js";

export const itemRoute = express.Router();

// Configure multer memory storage with 5MB limit
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_IMAGE_SIZE,
  },
});

// Multer error handling wrapper
const uploadMiddleware = (req, res, next) => {
  upload.single("image")(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      if (err.code === "LIMIT_FILE_SIZE") {
        return res
          .status(400)
          .json({ error: "File exceeds 5MB limit. Please upload a smaller image." });
      }
      return res.status(400).json({ error: err.message });
    } else if (err) {
      return res.status(400).json({ error: err.message });
    }
    next();
  });
};

// 🔹 1. GET ALL ITEMS (Customer Menu & Admin)
itemRoute.get("/", async (req, res) => {
  try {
    const msg = await getItemController(req);
    res.json({ message: msg });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 🔹 2. SERVE PERSISTENT IMAGE FROM GRIDFS
itemRoute.get("/image/:id", async (req, res) => {
  try {
    const fileId = req.params.id;
    const image = await getImageFromGridFS(fileId);

    if (!image) {
      return res.status(404).json({ error: "Image not found" });
    }

    res.setHeader("Content-Type", image.contentType);
    res.setHeader("Content-Length", image.length);
    // Cache for 24 hours to optimize client bandwidth
    res.setHeader("Cache-Control", "public, max-age=86400");

    image.stream.pipe(res);
  } catch (error) {
    console.error("Error serving image:", error);
    res.status(500).json({ error: "Failed to retrieve image" });
  }
});

// 🔹 3. STANDALONE IMAGE UPLOAD ENDPOINT (Admin Only)
itemRoute.post("/upload-image", adminCheck, uploadMiddleware, async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No image file provided." });
  }

  try {
    const stored = await storeImageInGridFS({
      buffer: req.file.buffer,
      originalName: req.file.originalname,
    });

    res.json({
      success: true,
      imageUrl: stored.imageUrl,
      fileId: stored.fileId,
      filename: stored.filename,
    });
  } catch (error) {
    console.error("Upload error:", error.message);
    res.status(400).json({ error: error.message });
  }
});

// 🔹 4. CREATE ITEM (Supports JSON or Multipart with Optional Image, Admin Only)
itemRoute.post("/add", adminCheck, uploadMiddleware, async (req, res) => {
  let uploadedFileId = null;

  try {
    // If a physical image file was uploaded via multipart/form-data
    if (req.file) {
      const stored = await storeImageInGridFS({
        buffer: req.file.buffer,
        originalName: req.file.originalname,
      });
      uploadedFileId = stored.fileId;
      req.body.imageUrl = stored.imageUrl;
    }

    const msg = await addItemController(req);

    // If item already exists or creation failed, delete the freshly uploaded file so no orphans remain
    if (msg === "Item Exists!" && uploadedFileId) {
      await forceDeleteGridFSFile(uploadedFileId);
    }

    res.json({ message: msg });
  } catch (error) {
    console.error("Add item error:", error);
    if (uploadedFileId) {
      await forceDeleteGridFSFile(uploadedFileId);
    }
    res.status(400).json({ error: error.message || "Failed to add item" });
  }
});

// 🔹 5. EDIT ITEM (Admin Only - Supports safe image replacement and cleanup)
itemRoute.put("/:id", adminCheck, uploadMiddleware, async (req, res) => {
  let newUploadedFileId = null;

  try {
    const item = await Item.findById(req.params.id);
    if (!item) {
      return res.status(404).json({ error: "Item not found" });
    }

    const oldImageUrl = item.imageUrl;

    if (req.file) {
      const stored = await storeImageInGridFS({
        buffer: req.file.buffer,
        originalName: req.file.originalname,
      });
      newUploadedFileId = stored.fileId;
      req.body.imageUrl = stored.imageUrl;
    }

    if (req.body.itemName !== undefined) item.itemName = req.body.itemName;
    if (req.body.itemPrice !== undefined) item.itemPrice = Number(req.body.itemPrice);
    if (req.body.category !== undefined) item.category = req.body.category;
    if (req.body.description !== undefined) item.description = req.body.description;
    if (req.body.isAvailable !== undefined) {
      item.isAvailable = req.body.isAvailable === true || req.body.isAvailable === "true";
    }
    if (req.body.imageUrl !== undefined) {
      item.imageUrl = req.body.imageUrl;
    }

    await item.save();

    // If image was replaced or removed, safely clean up old stored image from GridFS
    if (oldImageUrl && oldImageUrl !== item.imageUrl) {
      const match = oldImageUrl.match(/\/item\/image\/([0-9a-fA-F]{24})/);
      if (match) {
        await deleteImageFromGridFS(match[1]);
      }
    }

    res.json({ message: "Item updated successfully", item });
  } catch (error) {
    if (newUploadedFileId) {
      await forceDeleteGridFSFile(newUploadedFileId);
    }
    res.status(400).json({ error: error.message || "Failed to update item" });
  }
});

// 🔹 6. DELETE ITEM (Admin Only - Safely cleans up stored image if not shared)
itemRoute.delete("/:id", adminCheck, async (req, res) => {
  try {
    const item = await Item.findById(req.params.id);
    if (!item) {
      return res.status(404).json({ error: "Item not found" });
    }

    const oldImageUrl = item.imageUrl;
    await Item.findByIdAndDelete(req.params.id);

    if (oldImageUrl) {
      const match = oldImageUrl.match(/\/item\/image\/([0-9a-fA-F]{24})/);
      if (match) {
        await deleteImageFromGridFS(match[1]);
      }
    }

    res.json({ message: "Item deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message || "Failed to delete item" });
  }
});