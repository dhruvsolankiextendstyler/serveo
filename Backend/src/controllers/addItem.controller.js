import { Item } from "../models/item.models.js";

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

    const itemExists = await Item.findOne({ itemName });
    if (itemExists) return "Item Exists!";

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
    console.log("Item Created Successfully");
    return "Item Created Succssfully";
};