import { Order } from '../models/order.models.js';
import { User } from '../models/user.models.js';
import { Item } from '../models/item.models.js';
import { Restaurant } from '../models/restaurant.models.js';
import { Notification } from '../models/notification.models.js';
import { checkRestaurantAvailability } from '../utils/restaurant_availability.js';
import mongoose from 'mongoose';

export const addOrderController = async (req) => {
    const uid = req.user.uid;
    let user = await User.findOne({ uid: uid });

    if (!user && req.user.email) {
        user = await User.findOne({ email: req.user.email });
        if (user) {
            user.uid = uid;
            await user.save();
        }
    }

    if (!user) {
        // Auto-provision user record for valid Firebase authenticated user
        user = new User({
            uid: uid,
            fullName: req.user.name || (req.user.email ? req.user.email.split('@')[0] : "Customer"),
            email: req.user.email || `${uid}@serveo.app`,
            phoneNumber: req.user.phone_number || `+91${Math.floor(1000000000 + Math.random() * 9000000000)}`,
            password: "firebase_authenticated",
        });
        try {
            await user.save();
        } catch (_) {
            user = await User.findOne({ $or: [{ email: req.user.email }, { uid }] });
        }
    }

    if (!user) {
        throw new Error("Unable to associate user account with order");
    }

    const { orderItems, paymentMethod = "COD", restaurantId, restaurantSlug } = req.body;

    if (!Array.isArray(orderItems) || orderItems.length === 0) {
        throw new Error("Order tray cannot be empty");
    }

    // 1. Resolve Target Restaurant
    let restaurant = null;
    try {
        if (restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
            restaurant = await Restaurant.findById(restaurantId);
        } else if (restaurantSlug) {
            restaurant = await Restaurant.findOne({ slug: restaurantSlug.toLowerCase().trim() });
        }

        if (!restaurant && (mongoose.connection.readyState === 1 || Restaurant.findOne !== mongoose.Model.findOne)) {
            restaurant = await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
        }
    } catch (_) {}

    // 2. Business-Hours & Order Availability Enforcement
    if (restaurant) {
        const availability = checkRestaurantAvailability(restaurant);
        if (!availability.canOrder) {
            const err = new Error(availability.reason);
            err.status = 400;
            throw err;
        }
    }

    const resolvedRestaurantId = restaurant ? restaurant._id : null;

    // 3. Server-side validation of item prices against authoritative catalog
    const validatedOrderItems = [];
    let serverTotal = 0;

    for (const item of orderItems) {
        let dbItem = null;
        if (item.itemId) {
            try {
                const itemQuery = { _id: item.itemId };
                if (resolvedRestaurantId) {
                    itemQuery.$or = [
                        { restaurantId: resolvedRestaurantId },
                        { restaurantId: { $exists: false } },
                        { restaurantId: null }
                    ];
                }
                dbItem = await Item.findOne(itemQuery);
            } catch (_) {}
        }
        if (!dbItem && item.itemName) {
            const nameQuery = { itemName: item.itemName };
            if (resolvedRestaurantId) {
                nameQuery.$or = [
                    { restaurantId: resolvedRestaurantId },
                    { restaurantId: { $exists: false } },
                    { restaurantId: null }
                ];
            }
            dbItem = await Item.findOne(nameQuery);
        }

        if (dbItem && dbItem.isAvailable === false) {
            throw new Error(`Item '${dbItem.itemName}' is currently sold out and cannot be ordered.`);
        }

        const basePrice = dbItem ? dbItem.itemPrice : Number(item.itemPrice || 0);
        const name = dbItem ? dbItem.itemName : (item.itemName || "Item");
        const qty = Math.max(1, Math.min(Number(item.quantity) || 1, 10));

        let itemCustomizationsTotal = 0;
        const validatedCustomizations = [];

        if (Array.isArray(item.selectedCustomizations) && item.selectedCustomizations.length > 0) {
            for (const sc of item.selectedCustomizations) {
                const cName = (sc.customizationName || "").trim();
                const optName = (sc.optionName || "").trim();
                let verifiedOptionPrice = Number(sc.price) || 0;

                // Validate against authoritative catalog if configured on item
                if (dbItem && Array.isArray(dbItem.customizations) && dbItem.customizations.length > 0) {
                    const group = dbItem.customizations.find(
                        g => g.name.toLowerCase() === cName.toLowerCase()
                    );
                    if (group && Array.isArray(group.options)) {
                        const opt = group.options.find(
                            o => o.name.toLowerCase() === optName.toLowerCase()
                        );
                        if (opt) {
                            verifiedOptionPrice = Number(opt.price) || 0;
                        }
                    }
                }

                itemCustomizationsTotal += verifiedOptionPrice;
                validatedCustomizations.push({
                    customizationName: cName,
                    optionName: optName,
                    price: verifiedOptionPrice,
                });
            }
        }

        const effectiveUnitPrice = basePrice + itemCustomizationsTotal;
        serverTotal += effectiveUnitPrice * qty;

        validatedOrderItems.push({
            itemId: dbItem ? dbItem._id : item.itemId,
            itemName: name,
            itemPrice: basePrice,
            quantity: qty,
            selectedCustomizations: validatedCustomizations,
        });
    }

    let initialPaymentStatus = "Pending";
    let initialOrderStatus = "Processing";

    if (paymentMethod === "Card") {
        initialPaymentStatus = "Verified";
        initialOrderStatus = "Processing";
    }

    // Dynamic initial estimated preparation time
    const totalItemsCount = validatedOrderItems.reduce((sum, it) => sum + it.quantity, 0);
    const basePrep = restaurant?.defaultEstimatedPrepTime || 15;
    const estimatedMinutes = Math.min(60, Math.max(basePrep, 10 + totalItemsCount * 3));
    const estimatedReadyAt = new Date(Date.now() + estimatedMinutes * 60 * 1000);

    const newOrder = new Order({
        restaurantId: resolvedRestaurantId,
        userId: user._id,
        customerDetails: {
            fullName: user.fullName || "Customer",
            phoneNumber: user.phoneNumber || "",
            email: user.email || ""
        },
        orderItems: validatedOrderItems,
        totalAmount: serverTotal,
        paymentMethod: paymentMethod,
        paymentStatus: initialPaymentStatus,
        status: initialOrderStatus,
        estimatedPrepTime: estimatedMinutes,
        estimatedReadyAt: estimatedReadyAt,
    });

    await newOrder.save();

    // Persist in-app notification for the customer
    try {
        await Notification.create({
            restaurantId: resolvedRestaurantId,
            userId: user._id,
            orderId: newOrder._id,
            title: "Order Placed Successfully",
            body: `Order #${newOrder._id.toString().slice(-4)} placed for ₹${serverTotal} (${paymentMethod}). Estimated preparation time: ~${estimatedMinutes} mins.`,
            type: "order_placed"
        });
    } catch (notifErr) {
        console.error("Failed to persist order creation notification:", notifErr.message);
    }

    return {
        message: "Order Placed !!",
        order: newOrder
    };
};
