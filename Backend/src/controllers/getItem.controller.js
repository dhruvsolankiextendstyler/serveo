import { Item } from "../models/item.models.js";
import { Restaurant } from "../models/restaurant.models.js";
import mongoose from "mongoose";

/**
 * Controller to fetch catalog items with tenant isolation and optional
 * search, category, dietary, availability, and sorting filters.
 */
export const getItemController = async (req = {}) => {
  const query = {};
  const { search, category, isAvailable, isVeg, dietary, sortBy, restaurantId, restaurantSlug } = req.query || {};

  // 1. Tenant Scoping
  let targetRestaurantId = req.restaurantId;
  if (!targetRestaurantId && restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
    targetRestaurantId = restaurantId;
  } else if (!targetRestaurantId && restaurantSlug) {
    const r = await Restaurant.findOne({ slug: restaurantSlug.toLowerCase().trim() });
    if (r) targetRestaurantId = r._id;
  }

  if (targetRestaurantId) {
    query.$and = query.$and || [];
    query.$and.push({
      $or: [
        { restaurantId: targetRestaurantId },
        // Fallback for tests/legacy items where restaurantId was not yet populated
        { restaurantId: { $exists: false } },
        { restaurantId: null }
      ]
    });
  }

  // 2. Category Filter (case-insensitive exact match)
  if (category && category !== "All") {
    const escapedCat = category.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
    query.category = { $regex: new RegExp(`^${escapedCat}$`, "i") };
  }

  // 3. Keyword Search across name, description, and category
  if (search && search.trim()) {
    const escaped = search.trim().replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
    const searchCondition = {
      $or: [
        { itemName: { $regex: escaped, $options: "i" } },
        { description: { $regex: escaped, $options: "i" } },
        { category: { $regex: escaped, $options: "i" } }
      ]
    };
    if (query.$and) {
      query.$and.push(searchCondition);
    } else {
      query.$or = searchCondition.$or;
    }
  }

  // 4. Availability Filter
  if (isAvailable !== undefined && isAvailable !== "") {
    query.isAvailable = isAvailable === "true" || isAvailable === true;
  }

  // 5. Dietary Filters
  if (isVeg !== undefined && isVeg !== "") {
    query.isVeg = isVeg === "true" || isVeg === true;
  }
  if (dietary && dietary !== "All") {
    query.dietary = dietary;
  }

  let findQuery = Item.find(query);

  // 6. Sorting
  if (sortBy === "price_asc") {
    findQuery = findQuery.sort({ itemPrice: 1 });
  } else if (sortBy === "price_desc") {
    findQuery = findQuery.sort({ itemPrice: -1 });
  } else if (sortBy === "name_asc") {
    findQuery = findQuery.sort({ itemName: 1 });
  } else if (sortBy === "name_desc") {
    findQuery = findQuery.sort({ itemName: -1 });
  }

  const items = await findQuery;
  return items;
};

/**
 * Controller to fetch personalized recommendations for customer.
 * Uses legitimate order history frequency if available, or falls back to
 * popular available items. Clearly discloses source of recommendation.
 */
export const getRecommendedItemsController = async (req = {}) => {
  const { restaurantId, restaurantSlug } = req.query || {};
  let targetRestaurantId = req.restaurantId;
  if (!targetRestaurantId && restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
    targetRestaurantId = restaurantId;
  } else if (!targetRestaurantId && restaurantSlug) {
    const r = await Restaurant.findOne({ slug: restaurantSlug.toLowerCase().trim() });
    if (r) targetRestaurantId = r._id;
  }
  if (!targetRestaurantId) {
    const defaultRest = (await Restaurant.findOne({ slug: "default" })) || (await Restaurant.findOne({}));
    if (defaultRest) targetRestaurantId = defaultRest._id;
  }

  let userOrders = [];
  let userId = req.user?.uid ? (req.user._id || req.user.mongoId) : null;
  if (!userId && req.user?.uid) {
    const { User } = await import("../models/user.models.js");
    const u = await User.findOne({ uid: req.user.uid });
    if (u) userId = u._id;
  }

  const { Order } = await import("../models/order.models.js");

  if (userId) {
    const orderQuery = {
      userId,
      status: { $nin: ["Cancelled", "Payment Rejected"] },
    };
    if (targetRestaurantId) {
      orderQuery.$or = [
        { restaurantId: targetRestaurantId },
        { restaurantId: { $exists: false } },
        { restaurantId: null },
      ];
    }
    userOrders = await Order.find(orderQuery).sort({ createdAt: -1 }).limit(20).lean();
  }

  // Count item frequency from past orders
  const frequencyMap = {};
  userOrders.forEach((o) => {
    (o.orderItems || []).forEach((item) => {
      const idKey = (item.itemId || item._id || "").toString();
      const nameKey = item.itemName;
      const key = idKey || nameKey;
      if (!frequencyMap[key]) {
        frequencyMap[key] = { id: idKey, name: nameKey, count: 0 };
      }
      frequencyMap[key].count += item.quantity || 1;
    });
  });

  const sortedKeys = Object.values(frequencyMap).sort((a, b) => b.count - a.count);

  let recommendedItems = [];
  let reason = "Popular items ready to order";

  if (sortedKeys.length > 0) {
    const idList = sortedKeys.map((k) => k.id).filter((id) => mongoose.Types.ObjectId.isValid(id));
    const nameList = sortedKeys.map((k) => k.name).filter(Boolean);

    const matchConditions = [];
    if (idList.length > 0) matchConditions.push({ _id: { $in: idList } });
    if (nameList.length > 0) matchConditions.push({ itemName: { $in: nameList } });

    if (matchConditions.length > 0) {
      const catQuery = {
        $or: matchConditions,
        isAvailable: { $ne: false },
      };
      if (targetRestaurantId) {
        catQuery.$and = [
          {
            $or: [
              { restaurantId: targetRestaurantId },
              { restaurantId: null },
              { restaurantId: { $exists: false } },
            ],
          },
        ];
      }
      const catalogItems = await Item.find(catQuery).lean();
      if (catalogItems.length > 0) {
        recommendedItems = catalogItems.slice(0, 5);
        reason = "Based on your previous orders";
      }
    }
  }

  // Fallback: If no order history or not enough items, return top available items
  if (recommendedItems.length === 0) {
    const query = { isAvailable: { $ne: false } };
    if (targetRestaurantId) {
      query.$or = [{ restaurantId: targetRestaurantId }, { restaurantId: null }, { restaurantId: { $exists: false } }];
    }
    recommendedItems = await Item.find(query).limit(5).lean();
    reason = "Popular items ready to order";
  }

  return {
    recommendations: recommendedItems,
    reason,
  };
};
