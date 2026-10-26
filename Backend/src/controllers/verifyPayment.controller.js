import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { admin } from "../utils/firebase_app.js";

export const verifyPaymentController = async (req) => {
    const { orderId, verified } = req.body;
    if (!orderId) {
        throw new Error("Order ID is required");
    }

    const order = await Order.findById(orderId);
    if (!order) {
        throw new Error("Order not found");
    }

    const adminEmail = req.user?.email || "admin123@ad.in";
    const now = new Date();

    const isConfirmed = verified === true || verified === "true";

    if (isConfirmed) {
        // Concurrency-safe atomic update:
        // Transition paymentStatus to "Verified" and order status to "Preparing"
        const updatedOrder = await Order.findOneAndUpdate(
            { _id: orderId },
            {
                $set: {
                    paymentStatus: "Verified",
                    paymentVerifiedAt: now,
                    verifiedBy: adminEmail,
                    status: "Preparing" // Transitions into kitchen preparation workflow
                }
            },
            { new: true }
        ).populate("userId", "fullName phoneNumber email");

        // Send FCM notification to customer if fcmToken is available
        try {
            const customer = await User.findById(updatedOrder.userId);
            if (customer && customer.fcmToken) {
                const message = {
                    notification: {
                        title: "Serveo: Payment Verified!",
                        body: `Order #${updatedOrder._id.toString().slice(-4)} payment confirmed. Food preparation started!`,
                    },
                    token: customer.fcmToken,
                };
                admin.messaging().send(message)
                    .then(() => console.log("✅ Payment verification FCM sent to:", customer.email))
                    .catch((err) => console.error("❌ FCM Error:", err.message));
            }
        } catch (fcmErr) {
            console.error("FCM dispatch error:", fcmErr.message);
        }

        return {
            message: "Payment verified successfully. Order moved to preparation.",
            order: updatedOrder
        };
    } else {
        // Payment rejected / not received
        const updatedOrder = await Order.findOneAndUpdate(
            { _id: orderId },
            {
                $set: {
                    paymentStatus: "Rejected",
                    paymentVerifiedAt: now,
                    verifiedBy: adminEmail,
                    status: "Payment Rejected" // Kept out of preparation
                }
            },
            { new: true }
        ).populate("userId", "fullName phoneNumber email");

        try {
            const customer = await User.findById(updatedOrder.userId);
            if (customer && customer.fcmToken) {
                const message = {
                    notification: {
                        title: "Serveo: Payment Not Confirmed",
                        body: `We could not verify payment for Order #${updatedOrder._id.toString().slice(-4)}. Please check with the counter.`,
                    },
                    token: customer.fcmToken,
                };
                admin.messaging().send(message).catch(() => {});
            }
        } catch (_) {}

        return {
            message: "Payment claim rejected.",
            order: updatedOrder
        };
    }
};
