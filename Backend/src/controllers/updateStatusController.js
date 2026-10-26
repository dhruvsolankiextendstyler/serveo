import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { admin } from "../utils/firebase_app.js";

export const updateStatusController = async (req) => {
    const { id, newStatus } = req.body;
    if (!id) {
        throw new Error("Order ID is required");
    }
    if (!newStatus) {
        throw new Error("New status is required");
    }

    const allowedStatuses = [
        "Pending",
        "Processing",
        "Accepted",
        "Preparing",
        "Ready",
        "Completed",
        "Collected",
        "Pending Verification",
        "Payment Rejected",
        "Cancelled"
    ];

    if (!allowedStatuses.includes(newStatus)) {
        throw new Error(`Invalid status '${newStatus}'. Allowed: ${allowedStatuses.join(', ')}`);
    }

    const order = await Order.findById(id);
    if (!order) {
        throw new Error("Order not found");
    }

    // Do not allow transitioning a rejected payment order into kitchen preparation
    if (order.paymentStatus === "Rejected" && (newStatus === "Preparing" || newStatus === "Completed" || newStatus === "Ready")) {
        throw new Error("Cannot transition order with rejected payment to preparation");
    }

    order.status = newStatus;
    await order.save();

    if (newStatus === "Completed" || newStatus === "Ready") {
        const user = await User.findById(order.userId);
        if (user && user.fcmToken) {
            const message = {
                notification: {
                    title: "Serveo: Food is Ready!",
                    body: `Order #${order._id.toString().slice(-4)} is ready for pickup.`,
                },
                token: user.fcmToken,
            };
            admin.messaging().send(message)
                .then(() => console.log("✅ FCM sent to:", user.email))
                .catch((fcmError) => console.error("❌ FCM Error Details:", fcmError.message));
        }
    }
    return "Status Changed";
};