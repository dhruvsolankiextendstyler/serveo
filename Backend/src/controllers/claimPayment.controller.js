import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";

export const claimPaymentController = async (req) => {
    const uid = req.user.uid;
    const user = await User.findOne({ uid: uid });
    if (!user) {
        throw new Error("User account not found");
    }

    const { orderId } = req.body;
    if (!orderId) {
        throw new Error("Order ID is required");
    }

    const order = await Order.findById(orderId);
    if (!order) {
        throw new Error("Order not found");
    }

    // Ensure customer owns this order
    if (order.userId.toString() !== user._id.toString()) {
        throw new Error("Unauthorized to claim payment for this order");
    }

    // If order was already verified, do not revert
    if (order.paymentStatus === "Verified") {
        return {
            message: "Order payment has already been verified",
            order: order
        };
    }

    // Concurrency-safe atomic update
    const updatedOrder = await Order.findOneAndUpdate(
        { _id: orderId, paymentStatus: { $ne: "Verified" } },
        {
            $set: {
                paymentStatus: "Awaiting Verification",
                paymentClaimedAt: new Date()
            }
        },
        { new: true }
    );

    return {
        message: "Payment claim submitted. Awaiting store verification.",
        order: updatedOrder
    };
};
