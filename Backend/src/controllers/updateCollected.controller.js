import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { admin } from "../utils/firebase_app.js";
import { awardLoyaltyPointsForOrder } from "./loyalty.controller.js";
import { convertReferralOnFirstOrder } from "./referral.controller.js";

export const updateCollectedController = async (req) => {
    const {id} = req.body;
    const order = await Order.findById(id);
    if (!order) {
        throw new Error("Order not found");
    }
    order.status = "Collected";
    await order.save();

    try {
        await awardLoyaltyPointsForOrder(order);
        await convertReferralOnFirstOrder(order);
    } catch (err) {
        console.error("Error processing loyalty/referral on collection:", err.message);
    }

    return "Order Collected";
}