import mongoose from "mongoose";
import QRCode from "qrcode";
import { Restaurant } from "../models/restaurant.models.js";
import { Item } from "../models/item.models.js";
import { checkRestaurantAvailability } from "../utils/restaurant_availability.js";
import {
  storeImageInGridFS,
  deleteImageFromGridFS,
} from "../utils/image_storage.js";

/**
 * Helper to resolve restaurant by identifier (slug or ObjectId), or fallback to default.
 */
async function resolveRestaurant(identifier) {
  if (!identifier || identifier === "default") {
    return await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
  }

  if (mongoose.Types.ObjectId.isValid(identifier)) {
    const byId = await Restaurant.findById(identifier);
    if (byId) return byId;
  }

  const bySlug = await Restaurant.findOne({ slug: identifier.toLowerCase().trim() });
  if (bySlug) return bySlug;

  return await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
}

/**
 * 1. GET /restaurant/public/info
 * Public read-only restaurant profile & live availability status.
 * Never exposes credentials, admin emails, or internal secrets.
 */
export async function getPublicRestaurantInfoController(req, res) {
  try {
    const identifier = req.query.slug || req.query.id || req.params.identifier || "default";
    const restaurant = await resolveRestaurant(identifier);

    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const availability = checkRestaurantAvailability(restaurant);

    res.json({
      restaurant: {
        id: restaurant._id,
        name: restaurant.name,
        slug: restaurant.slug,
        description: restaurant.description,
        logoUrl: restaurant.logoUrl,
        bannerUrl: restaurant.bannerUrl,
        address: restaurant.address,
        contact: restaurant.contact,
        currency: restaurant.currency,
        currencySymbol: restaurant.currencySymbol,
        timezone: restaurant.timezone,
        operatingDays: restaurant.operatingDays,
        openingTime: restaurant.openingTime,
        closingTime: restaurant.closingTime,
        schedule: restaurant.schedule,
        isOrderAcceptancePaused: restaurant.isOrderAcceptancePaused,
        pauseReason: restaurant.pauseReason,
        defaultEstimatedPrepTime: restaurant.defaultEstimatedPrepTime,
        displayPreferences: restaurant.displayPreferences,
        availability,
      }
    });
  } catch (error) {
    console.error("Public Restaurant Info Error:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * 2. GET /restaurant/public/:identifier/menu
 * Public read-only menu for browsing without authentication.
 */
export async function getPublicRestaurantMenuController(req, res) {
  try {
    const identifier = req.params.identifier || req.query.slug || "default";
    const restaurant = await resolveRestaurant(identifier);

    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    const availability = checkRestaurantAvailability(restaurant);

    const items = await Item.find({
      $or: [
        { restaurantId: restaurant._id },
        { restaurantId: { $exists: false } },
        { restaurantId: null }
      ]
    }).sort({ category: 1, itemName: 1 }).lean();

    // Group items by category
    const categoriesMap = {};
    items.forEach(item => {
      const cat = item.category || "General";
      if (!categoriesMap[cat]) categoriesMap[cat] = [];
      categoriesMap[cat].push({
        id: item._id,
        name: item.itemName,
        price: item.itemPrice,
        category: item.category,
        description: item.description,
        isAvailable: item.isAvailable,
        imageUrl: item.imageUrl,
        isVeg: item.isVeg,
        dietary: item.dietary,
        customizations: item.customizations || []
      });
    });

    res.json({
      restaurant: {
        id: restaurant._id,
        name: restaurant.name,
        slug: restaurant.slug,
        description: restaurant.description,
        logoUrl: restaurant.logoUrl,
        address: restaurant.address,
        contact: restaurant.contact,
        currency: restaurant.currency,
        currencySymbol: restaurant.currencySymbol,
        availability,
      },
      categories: Object.keys(categoriesMap),
      menu: categoriesMap,
      totalItems: items.length
    });
  } catch (error) {
    console.error("Public Restaurant Menu Error:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * 3. GET /restaurant/admin/settings
 * Admin-scoped restaurant configuration.
 */
export async function getAdminRestaurantSettingsController(req, res) {
  try {
    const restaurant = req.restaurant || await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant profile not found for this administrator" });
    }

    const availability = checkRestaurantAvailability(restaurant);

    res.json({
      restaurant: {
        ...restaurant.toObject(),
        availability
      }
    });
  } catch (error) {
    console.error("Admin Restaurant Settings Error:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * 4. PUT/PATCH /restaurant/admin/settings
 * Updates business configuration with validation.
 */
export async function updateAdminRestaurantSettingsController(req, res) {
  try {
    const restaurant = req.restaurant || await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant profile not found" });
    }

    const body = req.body || {};

    // 1. Validate restaurant name
    if (body.name !== undefined) {
      const name = String(body.name).trim();
      if (!name) {
        return res.status(400).json({ error: "Restaurant name cannot be empty" });
      }
      restaurant.name = name;
    }

    if (body.description !== undefined) {
      restaurant.description = String(body.description).trim();
    }

    // 2. Validate Contact
    if (body.contact) {
      if (body.contact.phone !== undefined) {
        restaurant.contact.phone = String(body.contact.phone).trim();
      }
      if (body.contact.email !== undefined) {
        restaurant.contact.email = String(body.contact.email).trim();
      }
    }

    // 3. Validate Address
    if (body.address) {
      if (body.address.street !== undefined) restaurant.address.street = String(body.address.street).trim();
      if (body.address.city !== undefined) restaurant.address.city = String(body.address.city).trim();
      if (body.address.state !== undefined) restaurant.address.state = String(body.address.state).trim();
      if (body.address.postalCode !== undefined) restaurant.address.postalCode = String(body.address.postalCode).trim();
      if (body.address.country !== undefined) restaurant.address.country = String(body.address.country).trim();
    }

    // 4. Validate Operating Hours (HH:mm format)
    const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
    if (body.openingTime !== undefined) {
      const ot = String(body.openingTime).trim();
      if (!timeRegex.test(ot)) {
        return res.status(400).json({ error: "Opening time must be in HH:mm 24-hour format (e.g. 09:00)" });
      }
      restaurant.openingTime = ot;
    }

    if (body.closingTime !== undefined) {
      const ct = String(body.closingTime).trim();
      if (!timeRegex.test(ct)) {
        return res.status(400).json({ error: "Closing time must be in HH:mm 24-hour format (e.g. 22:00)" });
      }
      restaurant.closingTime = ct;
    }

    // 5. Validate Operating Days
    const validDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    if (body.operatingDays !== undefined) {
      if (!Array.isArray(body.operatingDays) || body.operatingDays.length === 0) {
        return res.status(400).json({ error: "At least one operating day must be selected" });
      }
      const invalid = body.operatingDays.filter(d => !validDays.includes(d));
      if (invalid.length > 0) {
        return res.status(400).json({ error: `Invalid day(s): ${invalid.join(', ')}` });
      }
      restaurant.operatingDays = body.operatingDays;
    }

    // 6. Schedule (Detailed per-day schedule)
    if (body.schedule !== undefined && Array.isArray(body.schedule)) {
      restaurant.schedule = body.schedule.filter(s => validDays.includes(s.day));
    }

    // 7. Currency & Locale
    if (body.currency !== undefined) {
      restaurant.currency = String(body.currency).toUpperCase().trim() || "INR";
      restaurant.currencySymbol = restaurant.currency === "INR" ? "₹" : "$";
    }
    if (body.currencySymbol !== undefined) {
      restaurant.currencySymbol = String(body.currencySymbol).trim();
    }

    // 8. Preparation time default
    if (body.defaultEstimatedPrepTime !== undefined) {
      const prep = Number(body.defaultEstimatedPrepTime);
      if (isNaN(prep) || prep < 5 || prep > 120) {
        return res.status(400).json({ error: "Estimated preparation time must be between 5 and 120 minutes" });
      }
      restaurant.defaultEstimatedPrepTime = prep;
    }

    // 9. Display preferences
    if (body.displayPreferences) {
      if (body.displayPreferences.announcement !== undefined) {
        restaurant.displayPreferences.announcement = String(body.displayPreferences.announcement).trim();
      }
      if (body.displayPreferences.showPrepTime !== undefined) {
        restaurant.displayPreferences.showPrepTime = Boolean(body.displayPreferences.showPrepTime);
      }
      if (body.displayPreferences.showDietaryBadges !== undefined) {
        restaurant.displayPreferences.showDietaryBadges = Boolean(body.displayPreferences.showDietaryBadges);
      }
    }

    // 10. Pause status
    if (body.isOrderAcceptancePaused !== undefined) {
      restaurant.isOrderAcceptancePaused = Boolean(body.isOrderAcceptancePaused);
    }
    if (body.pauseReason !== undefined) {
      restaurant.pauseReason = String(body.pauseReason).trim();
    }

    await restaurant.save();

    const availability = checkRestaurantAvailability(restaurant);

    res.json({
      message: "Restaurant business settings saved successfully",
      restaurant: {
        ...restaurant.toObject(),
        availability
      }
    });
  } catch (error) {
    console.error("Update Restaurant Settings Error:", error);
    res.status(400).json({ error: error.message || "Failed to update restaurant settings" });
  }
}

/**
 * 5. PATCH /restaurant/admin/pause-status
 * Quick toggle for pausing/resuming order acceptance.
 */
export async function updatePauseStatusController(req, res) {
  try {
    const restaurant = req.restaurant || await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant profile not found" });
    }

    const { isOrderAcceptancePaused, pauseReason } = req.body;

    restaurant.isOrderAcceptancePaused = Boolean(isOrderAcceptancePaused);
    if (pauseReason !== undefined) {
      restaurant.pauseReason = String(pauseReason).trim();
    }

    await restaurant.save();

    const availability = checkRestaurantAvailability(restaurant);

    res.json({
      message: restaurant.isOrderAcceptancePaused
        ? "Order acceptance paused successfully"
        : "Order acceptance resumed successfully",
      isOrderAcceptancePaused: restaurant.isOrderAcceptancePaused,
      pauseReason: restaurant.pauseReason,
      availability
    });
  } catch (error) {
    console.error("Update Pause Status Error:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * 6. POST /restaurant/admin/upload-logo
 * Uploads restaurant branding logo to GridFS.
 */
export async function uploadRestaurantLogoController(req, res) {
  if (!req.file) {
    return res.status(400).json({ error: "No image file provided." });
  }

  try {
    const restaurant = req.restaurant || await Restaurant.findById(req.restaurantId);
    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant profile not found" });
    }

    const oldLogoUrl = restaurant.logoUrl;

    const stored = await storeImageInGridFS({
      buffer: req.file.buffer,
      originalName: req.file.originalname,
    });

    restaurant.logoUrl = stored.imageUrl;
    await restaurant.save();

    // Clean up old logo if stored in GridFS
    if (oldLogoUrl) {
      const match = oldLogoUrl.match(/\/item\/image\/([0-9a-fA-F]{24})/);
      if (match) {
        await deleteImageFromGridFS(match[1]);
      }
    }

    res.json({
      success: true,
      message: "Restaurant logo updated successfully",
      logoUrl: stored.imageUrl
    });
  } catch (error) {
    console.error("Upload Logo Error:", error);
    res.status(400).json({ error: error.message });
  }
}

/**
 * 7. GET /restaurant/qr/:identifier
 * Generates a stable QR code for public menu browsing.
 */
export async function generateRestaurantQrController(req, res) {
  try {
    const identifier = req.params.identifier || (req.restaurant ? req.restaurant.slug : "default");
    const restaurant = await resolveRestaurant(identifier);

    if (!restaurant) {
      return res.status(404).json({ error: "Restaurant not found" });
    }

    // Build stable public URL
    const host = req.get("host");
    const protocol = req.protocol === "https" || req.get("x-forwarded-proto") === "https" ? "https" : "http";
    const publicMenuUrl = `${protocol}://${host}/menu/${restaurant.slug}`;

    const dataUrl = await QRCode.toDataURL(publicMenuUrl, {
      errorCorrectionLevel: "H",
      margin: 2,
      width: 400,
      color: {
        dark: "#1A1A1A",
        light: "#FFFFFF"
      }
    });

    if (req.query.format === "image") {
      const base64Data = dataUrl.replace(/^data:image\/png;base64,/, "");
      const imgBuffer = Buffer.from(base64Data, "base64");
      res.setHeader("Content-Type", "image/png");
      res.setHeader("Content-Disposition", `inline; filename="qr-menu-${restaurant.slug}.png"`);
      return res.send(imgBuffer);
    }

    res.json({
      restaurantName: restaurant.name,
      restaurantSlug: restaurant.slug,
      menuUrl: publicMenuUrl,
      qrDataUrl: dataUrl
    });
  } catch (error) {
    console.error("Generate QR Error:", error);
    res.status(500).json({ error: error.message });
  }
}

/**
 * 8. GET /menu/:identifier
 * Server-rendered, ultra-lightweight, responsive mobile & desktop web menu.
 * Works on any browser without needing app installation or login.
 */
export async function renderPublicWebMenuController(req, res) {
  try {
    const identifier = req.params.identifier || "default";
    const restaurant = await resolveRestaurant(identifier);

    if (!restaurant) {
      return res.status(404).send(`
        <!DOCTYPE html>
        <html><head><title>Restaurant Not Found</title></head>
        <body style="font-family: sans-serif; text-align: center; padding: 50px;">
          <h2>Restaurant Not Found</h2>
          <p>The requested restaurant menu could not be located.</p>
        </body></html>
      `);
    }

    const availability = checkRestaurantAvailability(restaurant);
    const items = await Item.find({
      $or: [
        { restaurantId: restaurant._id },
        { restaurantId: { $exists: false } },
        { restaurantId: null }
      ]
    }).sort({ category: 1, itemName: 1 }).lean();

    // Group items by category
    const categoriesMap = {};
    items.forEach(item => {
      const cat = item.category || "General";
      if (!categoriesMap[cat]) categoriesMap[cat] = [];
      categoriesMap[cat].push(item);
    });

    const categories = Object.keys(categoriesMap);

    // Status badge style
    let statusBadgeColor = "#10B981";
    let statusBadgeText = `🟢 Open Now (${restaurant.openingTime} - ${restaurant.closingTime})`;
    if (availability.status === "PAUSED") {
      statusBadgeColor = "#F59E0B";
      statusBadgeText = `⏸ Temporarily Paused: ${availability.reason}`;
    } else if (availability.status === "CLOSED") {
      statusBadgeColor = "#EF4444";
      statusBadgeText = `🔴 Currently Closed: ${availability.reason}`;
    }

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>${escapeHtml(restaurant.name)} — Serveo Menu</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #0F0F11;
      color: #F3F4F6;
      line-height: 1.5;
      padding-bottom: 60px;
    }
    .header {
      background: #18181B;
      border-bottom: 1px solid #27272A;
      padding: 24px 20px;
      text-align: center;
    }
    .logo-container {
      width: 72px;
      height: 72px;
      border-radius: 16px;
      background: #FACC15;
      color: #000;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      font-weight: bold;
      margin-bottom: 12px;
      overflow: hidden;
      box-shadow: 0 4px 12px rgba(250, 204, 21, 0.25);
    }
    .logo-container img { width: 100%; height: 100%; object-fit: cover; }
    h1 { font-size: 24px; font-weight: 800; color: #FFFFFF; letter-spacing: -0.5px; }
    .desc { font-size: 13px; color: #A1A1AA; margin-top: 4px; max-width: 500px; margin-left: auto; margin-right: auto; }
    .contact-info { font-size: 12px; color: #71717A; margin-top: 8px; }
    .status-badge {
      display: inline-block;
      margin-top: 14px;
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid ${statusBadgeColor};
      color: ${statusBadgeColor};
    }
    .container { max-width: 760px; margin: 0 auto; padding: 16px; }
    .announcement {
      background: #27272A;
      border-left: 4px solid #FACC15;
      padding: 12px 16px;
      border-radius: 8px;
      font-size: 13px;
      color: #E4E4E7;
      margin-bottom: 20px;
    }
    .cat-nav {
      position: sticky;
      top: 0;
      background: #0F0F11;
      padding: 10px 0;
      overflow-x: auto;
      white-space: nowrap;
      border-bottom: 1px solid #27272A;
      margin-bottom: 20px;
      z-index: 10;
      -webkit-overflow-scrolling: touch;
    }
    .cat-pill {
      display: inline-block;
      padding: 6px 14px;
      margin-right: 8px;
      border-radius: 20px;
      background: #18181B;
      border: 1px solid #27272A;
      color: #E4E4E7;
      text-decoration: none;
      font-size: 13px;
      font-weight: 600;
    }
    .cat-pill:hover, .cat-pill.active {
      background: #FACC15;
      color: #000;
      border-color: #FACC15;
    }
    .category-section { margin-bottom: 32px; scroll-margin-top: 60px; }
    .category-title {
      font-size: 18px;
      font-weight: 700;
      color: #FACC15;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .menu-card {
      background: #18181B;
      border: 1px solid #27272A;
      border-radius: 14px;
      padding: 16px;
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
    }
    .card-info { flex: 1; }
    .item-header { display: flex; align-items: center; gap: 8px; }
    .diet-badge {
      font-size: 10px;
      padding: 2px 6px;
      border-radius: 4px;
      font-weight: 700;
    }
    .veg { background: rgba(34, 197, 94, 0.15); color: #22C55E; border: 1px solid #22C55E; }
    .non-veg { background: rgba(239, 68, 68, 0.15); color: #EF4444; border: 1px solid #EF4444; }
    .item-name { font-size: 16px; font-weight: 700; color: #FFFFFF; }
    .item-price { font-size: 16px; font-weight: 700; color: #FACC15; margin-top: 4px; }
    .item-desc { font-size: 13px; color: #A1A1AA; margin-top: 6px; }
    .sold-out { opacity: 0.55; }
    .sold-out-badge {
      display: inline-block;
      margin-top: 6px;
      font-size: 11px;
      font-weight: bold;
      color: #EF4444;
      background: rgba(239, 68, 68, 0.1);
      padding: 2px 8px;
      border-radius: 4px;
    }
    .footer-note {
      text-align: center;
      font-size: 12px;
      color: #71717A;
      margin-top: 40px;
      border-top: 1px solid #27272A;
      padding-top: 20px;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo-container">
      ${restaurant.logoUrl ? `<img src="${escapeHtml(restaurant.logoUrl)}" alt="Logo" onerror="this.style.display='none';this.parentNode.innerHTML='${escapeHtml(restaurant.name[0] || 'S')}';">` : escapeHtml(restaurant.name[0] || 'S')}
    </div>
    <h1>${escapeHtml(restaurant.name)}</h1>
    <div class="desc">${escapeHtml(restaurant.description)}</div>
    ${restaurant.address?.street ? `<div class="contact-info">📍 ${escapeHtml(restaurant.address.street)}, ${escapeHtml(restaurant.address.city || '')} • 📞 ${escapeHtml(restaurant.contact?.phone || '')}</div>` : ''}
    <div class="status-badge">${statusBadgeText}</div>
  </div>

  <div class="container">
    ${restaurant.displayPreferences?.announcement ? `<div class="announcement">📢 ${escapeHtml(restaurant.displayPreferences.announcement)}</div>` : ''}

    <nav class="cat-nav">
      ${categories.map(cat => `<a href="#cat-${escapeHtml(cat.replace(/\s+/g, '-'))}" class="cat-pill">${escapeHtml(cat)} (${categoriesMap[cat].length})</a>`).join('')}
    </nav>

    ${categories.map(cat => `
      <section class="category-section" id="cat-${escapeHtml(cat.replace(/\s+/g, '-'))}">
        <div class="category-title">
          <span>${escapeHtml(cat)}</span>
        </div>
        ${categoriesMap[cat].map(item => `
          <div class="menu-card ${item.isAvailable ? '' : 'sold-out'}">
            <div class="card-info">
              <div class="item-header">
                <span class="diet-badge ${item.isVeg ? 'veg' : 'non-veg'}">${item.isVeg ? 'VEG' : 'NON-VEG'}</span>
                <span class="item-name">${escapeHtml(item.itemName)}</span>
              </div>
              <div class="item-price">₹${item.itemPrice}</div>
              ${item.description ? `<div class="item-desc">${escapeHtml(item.description)}</div>` : ''}
              ${!item.isAvailable ? `<div class="sold-out-badge">Sold Out</div>` : ''}
            </div>
          </div>
        `).join('')}
      </section>
    `).join('')}

    <div class="footer-note">
      <p>Powered by Serveo • Digital Food Ordering Platform</p>
      <p style="margin-top: 4px;">To place orders for counter pickup, open the Serveo App or visit the service counter.</p>
    </div>
  </div>
</body>
</html>`;

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.send(html);
  } catch (error) {
    console.error("Render Web Menu Error:", error);
    res.status(500).send("Internal Server Error rendering menu");
  }
}

function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

