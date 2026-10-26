import { Item } from "../models/item.models.js";

/**
 * Controller to fetch catalog items with optional search, category, dietary, availability, and sorting filters.
 * Applies safe regex escaping to prevent query injection / ReDoS.
 */
export const getItemController = async (req = {}) => {
  const query = {};
  const { search, category, isAvailable, isVeg, dietary, sortBy } = req.query || {};

  // 1. Category Filter (case-insensitive exact match)
  if (category && category !== "All") {
    const escapedCat = category.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
    query.category = { $regex: new RegExp(`^${escapedCat}$`, "i") };
  }

  // 2. Keyword Search across name, description, and category
  if (search && search.trim()) {
    const escaped = search.trim().replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
    query.$or = [
      { itemName: { $regex: escaped, $options: "i" } },
      { description: { $regex: escaped, $options: "i" } },
      { category: { $regex: escaped, $options: "i" } }
    ];
  }

  // 3. Availability Filter
  if (isAvailable !== undefined && isAvailable !== "") {
    query.isAvailable = isAvailable === "true" || isAvailable === true;
  }

  // 4. Dietary Filters
  if (isVeg !== undefined && isVeg !== "") {
    query.isVeg = isVeg === "true" || isVeg === true;
  }
  if (dietary && dietary !== "All") {
    query.dietary = dietary;
  }

  let findQuery = Item.find(query);

  // 5. Sorting
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