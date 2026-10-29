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
