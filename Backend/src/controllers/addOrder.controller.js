import { Order } from '../models/order.models.js'
import { User } from '../models/user.models.js'
import { Item } from '../models/item.models.js'

export const addOrderController = async (req) => {
    const uid = req.user.uid
    let user = await User.findOne({uid: uid})

    if (!user && req.user.email) {
        user = await User.findOne({email: req.user.email})
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

    const { orderItems, paymentMethod = "COD" } = req.body

    if (!Array.isArray(orderItems) || orderItems.length === 0) {
        throw new Error("Order tray cannot be empty");
    }

    // Server-side validation of item prices against Item catalog to ensure source of truth
    const validatedOrderItems = [];
    let serverTotal = 0;

    for (const item of orderItems) {
        let dbItem = null;
        if (item.itemId) {
            try {
                dbItem = await Item.findById(item.itemId);
            } catch (_) {}
        }
        if (!dbItem && item.itemName) {
            dbItem = await Item.findOne({ itemName: item.itemName });
        }

        if (dbItem && dbItem.isAvailable === false) {
            throw new Error(`Item '${dbItem.itemName}' is currently sold out and cannot be ordered.`);
        }

        const price = dbItem ? dbItem.itemPrice : Number(item.itemPrice || 0);
        const name = dbItem ? dbItem.itemName : (item.itemName || "Item");
        const qty = Math.max(1, Math.min(Number(item.quantity) || 1, 10));
        serverTotal += price * qty;

        validatedOrderItems.push({
            itemId: dbItem ? dbItem._id : item.itemId,
            itemName: name,
            itemPrice: price,
            quantity: qty
        });
    }

    let initialPaymentStatus = "Pending";
    let initialOrderStatus = "Processing";

    if (paymentMethod === "Card") {
        initialPaymentStatus = "Verified";
        initialOrderStatus = "Processing";
    }

    const newOrder = new Order({
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
        status: initialOrderStatus
    });

    await newOrder.save();

    return {
        message: "Order Placed !!",
        order: newOrder
    };
}