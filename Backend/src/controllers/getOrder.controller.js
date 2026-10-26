import { Order } from "../models/order.models.js";

export const getOrderController = async () => {
    const orders = await Order.find()
        .populate("userId", "fullName phoneNumber email")
        .sort({createdAt: 1})
    return orders
}