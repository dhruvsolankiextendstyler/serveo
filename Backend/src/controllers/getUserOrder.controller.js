import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";

export const getUserOrderController = async (req) => {
    const uid = req.user.uid;
    let user = await User.findOne({ uid: uid });
    if (!user && req.user.email) {
        user = await User.findOne({ email: req.user.email });
    }
    if (!user) {
        return [];
    }
    const orders = await Order.find({ userId: user._id }).sort({ createdAt: -1 });
    return orders;
};