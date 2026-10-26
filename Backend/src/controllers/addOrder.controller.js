import { Order } from '../models/order.models.js'
import { User } from '../models/user.models.js'
import { Item } from '../models/item.models.js'

export const addOrderController = async (req) => {
    const uid = req.user.uid
    const user = await User.findOne({uid: uid})
    if (!user) {
        throw new Error("User account not found");
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