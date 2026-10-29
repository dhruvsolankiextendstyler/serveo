import { Order } from "../models/order.models.js";

export const getOrderController = async (req = {}) => {
    const query = {};
    if (req.restaurantId) {
        query.$or = [
            { restaurantId: req.restaurantId },
            // Include legacy orders for default restaurant if applicable
            { restaurantId: { $exists: false } },
            { restaurantId: null }
        ];
    }
    const orders = await Order.find(query)
        .populate("userId", "fullName phoneNumber email")
        .sort({createdAt: 1});
    return orders;
};
