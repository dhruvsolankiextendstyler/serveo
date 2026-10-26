import mongoose from "mongoose";
import crypto from "crypto";
import heicConvert from "heic-convert";
import { Readable } from "stream";

let bucket = null;

export const getGridFSBucket = () => {
  if (!bucket && mongoose.connection.readyState === 1) {
    bucket = new mongoose.mongo.GridFSBucket(mongoose.connection.db, {
      bucketName: "food_images",
    });
  }
  return bucket;
};

export const ALLOWED_IMAGE_TYPES = {
  JPEG: "image/jpeg",
  PNG: "image/png",
  WEBP: "image/webp",
  GIF: "image/gif",
  BMP: "image/bmp",
  HEIC: "image/heic",
};

export const MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5 MB

/**
 * Validates actual file content via magic bytes rather than trusting file extension.
 * Supports JPEG, PNG, GIF, WebP, BMP, and HEIC/HEIF.
 */
export function detectImageSignature(buffer) {
  if (!buffer || buffer.length < 12) return null;

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return { mime: "image/png", ext: "png" };
  }

  // GIF: GIF87a or GIF89a
  if (
    buffer[0] === 0x47 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x38 &&
    (buffer[4] === 0x37 || buffer[4] === 0x39) &&
    buffer[5] === 0x61
  ) {
    return { mime: "image/gif", ext: "gif" };
  }

  // WebP: RIFF....WEBP
  if (
    buffer.toString("ascii", 0, 4) === "RIFF" &&
    buffer.toString("ascii", 8, 12) === "WEBP"
  ) {
    return { mime: "image/webp", ext: "webp" };
  }

  // BMP: BM (0x42 0x4D)
  if (buffer[0] === 0x42 && buffer[1] === 0x4d) {
    return { mime: "image/bmp", ext: "bmp" };
  }

  // HEIC / HEIF: bytes 4-8 are 'ftyp'
  const brand = buffer.toString("ascii", 4, 8);
  if (brand === "ftyp") {
    const majorBrand = buffer.toString("ascii", 8, 12).toLowerCase();
    const compatibleBrands = [
      "heic",
      "heix",
      "hevc",
      "heim",
      "heis",
      "mif1",
      "msf1",
    ];
    if (compatibleBrands.includes(majorBrand)) {
      return { mime: "image/heic", ext: "heic" };
    }
  }

  return null;
}

/**
 * Stores an image buffer persistently into MongoDB GridFS.
 * Automatically handles HEIC conversion to JPEG.
 */
export async function storeImageInGridFS({ buffer, originalName }) {
  const gridBucket = getGridFSBucket();
  if (!gridBucket) {
    throw new Error("GridFS bucket is not initialized. Ensure database is connected.");
  }

  if (buffer.length > MAX_IMAGE_SIZE) {
    throw new Error("File exceeds 5MB limit. Please upload an image under 5MB.");
  }

  const detected = detectImageSignature(buffer);
  if (!detected) {
    throw new Error(
      "Unsupported image format. Allowed formats: JPEG, PNG, WebP, GIF, BMP, HEIC/HEIF."
    );
  }

  let finalBuffer = buffer;
  let finalMime = detected.mime;
  let finalExt = detected.ext;

  if (detected.mime === "image/heic") {
    try {
      finalBuffer = await heicConvert({
        buffer,
        format: "JPEG",
        quality: 0.9,
      });
      finalMime = "image/jpeg";
      finalExt = "jpg";
    } catch (err) {
      throw new Error(`Failed to convert HEIC image: ${err.message}`);
    }
  }

  // Safe collision-resistant filename (never trust raw user filenames)
  const safeFilename = `item_${Date.now()}_${crypto.randomBytes(6).toString("hex")}.${finalExt}`;

  return new Promise((resolve, reject) => {
    const uploadStream = gridBucket.openUploadStream(safeFilename, {
      contentType: finalMime,
      metadata: {
        originalName: originalName || safeFilename,
        uploadedAt: new Date(),
        size: finalBuffer.length,
      },
    });

    const readable = Readable.from(finalBuffer);
    readable
      .pipe(uploadStream)
      .on("error", reject)
      .on("finish", () => {
        resolve({
          fileId: uploadStream.id.toString(),
          filename: safeFilename,
          contentType: finalMime,
          size: finalBuffer.length,
          imageUrl: `/item/image/${uploadStream.id.toString()}`,
        });
      });
  });
}

/**
 * Retrieves an image stream and metadata from MongoDB GridFS.
 */
export async function getImageFromGridFS(idString) {
  if (!mongoose.Types.ObjectId.isValid(idString)) {
    return null;
  }
  const gridBucket = getGridFSBucket();
  if (!gridBucket) return null;

  const objectId = new mongoose.Types.ObjectId(idString);
  const files = await gridBucket.find({ _id: objectId }).toArray();
  if (!files || files.length === 0) {
    return null;
  }

  const file = files[0];
  const stream = gridBucket.openDownloadStream(objectId);
  return {
    stream,
    contentType: file.contentType || "image/jpeg",
    length: file.length,
    filename: file.filename,
  };
}

/**
 * Safely removes an image from GridFS only if no item references it.
 */
export async function deleteImageFromGridFS(idString) {
  if (!mongoose.Types.ObjectId.isValid(idString)) return false;
  const gridBucket = getGridFSBucket();
  if (!gridBucket) return false;

  const { Item } = await import("../models/item.models.js");
  const count = await Item.countDocuments({
    imageUrl: { $regex: idString },
  });

  if (count > 0) {
    // Still referenced by an item, do not delete
    return false;
  }

  try {
    await gridBucket.delete(new mongoose.Types.ObjectId(idString));
    return true;
  } catch {
    return false;
  }
}

/**
 * Force deletes an orphaned image from GridFS (e.g. when item creation failed).
 */
export async function forceDeleteGridFSFile(idString) {
  if (!mongoose.Types.ObjectId.isValid(idString)) return;
  const gridBucket = getGridFSBucket();
  if (!gridBucket) return;
  try {
    await gridBucket.delete(new mongoose.Types.ObjectId(idString));
  } catch {
    // Ignore error if file already deleted
  }
}
