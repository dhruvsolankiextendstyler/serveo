import mongoose from "mongoose";
import { Restaurant } from "../models/restaurant.models.js";
import { Item } from "../models/item.models.js";
import { Order } from "../models/order.models.js";
import { Notification } from "../models/notification.models.js";
import { Feedback } from "../models/feedback.models.js";

/**
 * Initializes the default restaurant and safely backfills legacy records
 * with the default restaurantId if missing.
 *
 * This operation is strictly idempotent:
 * - Creates default restaurant if none exists.
 * - Backfills unassociated Item, Order, Notification, Feedback records.
 * - Drops legacy global itemName index and establishes tenant-scoped compound index.
 */
export async function initDefaultRestaurant() {
  try {
    let defaultRestaurant = await Restaurant.findOne({ slug: "default" });

    if (!defaultRestaurant) {
      defaultRestaurant = new Restaurant({
        name: "Serveo",
        slug: "default",
        description: "Fresh meals & quick snacks ready for counter pickup",
        address: {
          street: "Central Food Court, Campus Block A",
          city: "Bengaluru",
          state: "Karnataka",
          postalCode: "560001",
          country: "India",
        },
        contact: {
          phone: "+91 98765 43210",
          email: "support@serveo.app",
        },
        currency: "INR",
        currencySymbol: "₹",
        timezone: "Asia/Kolkata",
        operatingDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
        openingTime: "09:00",
        closingTime: "22:00",
        isOrderAcceptancePaused: false,
        pauseReason: "",
        defaultEstimatedPrepTime: 20,
        displayPreferences: {
          announcement: "Welcome to Serveo! Fresh meals prepared to order.",
          showPrepTime: true,
          showDietaryBadges: true,
        },
        adminEmails: ["admin123@ad.in"],
        adminUids: [],
        isActive: true,
      });

      await defaultRestaurant.save();
      console.log("✅ Default restaurant 'Serveo' initialized successfully.");
    }

    const defaultId = defaultRestaurant._id;

    // 1. Backfill legacy items missing restaurantId
    const itemUpdateResult = await Item.updateMany(
      { $or: [{ restaurantId: { $exists: false } }, { restaurantId: null }] },
      { $set: { restaurantId: defaultId } }
    );
    if (itemUpdateResult.modifiedCount > 0) {
      console.log(`✅ Backfilled ${itemUpdateResult.modifiedCount} legacy menu items with default restaurantId.`);
    }

    // Drop legacy global itemName unique index if it exists to allow multi-tenant duplicate names across restaurants
    try {
      await Item.collection.dropIndex("itemName_1");
    } catch (_) {
      // Index might not exist or already dropped
    }

    // 2. Backfill legacy orders missing restaurantId
    const orderUpdateResult = await Order.updateMany(
      { $or: [{ restaurantId: { $exists: false } }, { restaurantId: null }] },
      { $set: { restaurantId: defaultId } }
    );
    if (orderUpdateResult.modifiedCount > 0) {
      console.log(`✅ Backfilled ${orderUpdateResult.modifiedCount} legacy orders with default restaurantId.`);
    }

    // 3. Backfill legacy notifications missing restaurantId
    const notifUpdateResult = await Notification.updateMany(
      { $or: [{ restaurantId: { $exists: false } }, { restaurantId: null }] },
      { $set: { restaurantId: defaultId } }
    );
    if (notifUpdateResult.modifiedCount > 0) {
      console.log(`✅ Backfilled ${notifUpdateResult.modifiedCount} legacy notifications with default restaurantId.`);
    }

    // 4. Backfill legacy feedback missing restaurantId
    const feedbackUpdateResult = await Feedback.updateMany(
      { $or: [{ restaurantId: { $exists: false } }, { restaurantId: null }] },
      { $set: { restaurantId: defaultId } }
    );
    if (feedbackUpdateResult.modifiedCount > 0) {
      console.log(`✅ Backfilled ${feedbackUpdateResult.modifiedCount} legacy feedbacks with default restaurantId.`);
    }

    return defaultRestaurant;
  } catch (error) {
    console.error("⚠️ Error initializing default restaurant:", error.message);
    return null;
  }
}

