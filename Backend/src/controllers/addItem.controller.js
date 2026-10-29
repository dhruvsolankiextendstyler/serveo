import { Item } from "../models/item.models.js";
import { Restaurant } from "../models/restaurant.models.js";
import { getPlanConfig } from "../models/plan.models.js";
import mongoose from "mongoose";

export const addItemController = async (req) => {
    const itemName = req.body.itemName?.trim();
    if (!itemName) {
        throw new Error("Item name is required");
    }
    const itemPrice = Number(req.body.itemPrice);
    if (isNaN(itemPrice) || itemPrice <= 0) {
        throw new Error("Item price must be a valid positive number");
    }
    const category = req.body.category?.trim();
    if (!category) {
        throw new Error("Category is required");
    }

    // Resolve tenant restaurantId from admin auth context, or fallback to default
    let targetRestaurantId = req.restaurantId;
    if (!targetRestaurantId) {
        try {
            if (mongoose.connection.readyState === 1 || Restaurant.findOne !== mongoose.Model.findOne) {
                const defaultRest = await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
                targetRestaurantId = defaultRest ? defaultRest._id : null;
            }
        } catch (_) {}
    }

    const itemQuery = { itemName };
    if (targetRestaurantId) {
        itemQuery.restaurantId = targetRestaurantId;
    }

    const itemExists = await Item.findOne(itemQuery);
    if (itemExists) return "Item Exists!";

    // Subscription Plan Limit Enforcement: Max Active Menu Items
    if (targetRestaurantId && (mongoose.connection.readyState === 1 || Restaurant.findById !== mongoose.Model.findById)) {
        try {
            const restaurant = await Restaurant.findById(targetRestaurantId);
            if (restaurant) {
                const planConfig = getPlanConfig(restaurant.subscription?.planId);
                const maxItems = restaurant.subscription?.customLimits?.maxActiveMenuItems ?? planConfig.maxActiveMenuItems;

                const activeCount = await Item.countDocuments({
                    restaurantId: targetRestaurantId,
                    isAvailable: { $ne: false },
                });

                if (activeCount >= maxItems) {
                    const err = new Error(
                        `Menu item limit reached for your ${planConfig.name} plan (${activeCount}/${maxItems}). Please upgrade your plan to add more items.`
                    );
                    err.status = 403;
                    err.code = "PLAN_LIMIT_REACHED";
                    err.limitType = "maxActiveMenuItems";
                    throw err;
                }
            }
        } catch (planErr) {
            if (planErr.code === "PLAN_LIMIT_REACHED" || planErr.status === 403) throw planErr;
        }
    }

    let customizations = [];
    if (req.body.customizations) {
        try {
            customizations = typeof req.body.customizations === 'string'
                ? JSON.parse(req.body.customizations)
                : req.body.customizations;
            if (!Array.isArray(customizations)) customizations = [];
        } catch (_) {}
    }

    const newItem = new Item({
        restaurantId: targetRestaurantId,
        itemName,
        itemPrice,
        category,
        description: req.body.description || "",
        isAvailable: req.body.isAvailable !== undefined ? (req.body.isAvailable === true || req.body.isAvailable === 'true') : true,
        imageUrl: req.body.imageUrl || "",
        isVeg: req.body.isVeg !== undefined ? (req.body.isVeg === true || req.body.isVeg === 'true') : true,
        dietary: req.body.dietary || "Veg",
        customizations,
    });
    await newItem.save();
    console.log("Item Created Successfully for restaurant:", targetRestaurantId);
    return "Item Created Succssfully";
};
