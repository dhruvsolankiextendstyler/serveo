import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { Notification } from "../models/notification.models.js";
import { admin } from "../utils/firebase_app.js";

export const verifyPaymentController = async (req) => {
    const { orderId, verified, rejectionReason } = req.body;
    if (!orderId) {
        const error = new Error("Order ID is required");
        error.status = 400;
        throw error;
    }

    const order = await Order.findById(orderId);
    if (!order) {
        const error = new Error("Order not found");
        error.status = 404;
        throw error;
    }

    // Cross-tenant verification protection: Admin cannot verify another restaurant's orders
    if (req.restaurantId && order.restaurantId && order.restaurantId.toString() !== req.restaurantId.toString()) {
        const error = new Error("Unauthorized to verify payment for an order from another restaurant");
        error.status = 403;
        throw error;
    }

    const adminEmail = req.user?.email || "admin123@ad.in";
    const now = new Date();
    const isConfirmed = verified === true || verified === "true";

    // Prevent duplicate actions on already finalized attempt
    if (order.paymentStatus === "Verified") {
        const error = new Error("This order has already been verified");
        error.status = 400;
        throw error;
    }
    if (order.paymentStatus === "Rejected" && !isConfirmed && order.status === "Payment Rejected") {
        const error = new Error("This verification attempt has already been rejected");
        error.status = 400;
        throw error;
    }

    // Preserve and update attempt history
    const attempts = Array.isArray(order.verificationAttempts) ? [...order.verificationAttempts] : [];
    const latestAttempt = attempts.length > 0 ? attempts[attempts.length - 1] : null;

    const resolvedReason = isConfirmed ? null : (rejectionReason?.trim() || "Payment could not be verified");

    if (latestAttempt && latestAttempt.status === "Pending") {
        latestAttempt.status = isConfirmed ? "Verified" : "Rejected";
        latestAttempt.reviewedAt = now;
        latestAttempt.reviewedBy = adminEmail;
        latestAttempt.rejectionReason = resolvedReason;
    } else {
        // If legacy order or attempt array was empty, record attempt
        attempts.push({
            attemptNumber: attempts.length + 1,
            submittedAt: order.paymentClaimedAt || now,
            status: isConfirmed ? "Verified" : "Rejected",
            reviewedAt: now,
            reviewedBy: adminEmail,
            rejectionReason: resolvedReason
        });
    }

    // Dynamic estimated preparation time calculation when entering "Preparing"
    let prepMinutes = order.estimatedPrepTime;
    let readyAt = order.estimatedReadyAt;

    if (isConfirmed) {
        const totalQty = (order.orderItems || []).reduce((sum, item) => sum + (Number(item.quantity) || 1), 0);
        prepMinutes = prepMinutes || Math.min(45, Math.max(15, 10 + totalQty * 3));
        readyAt = new Date(now.getTime() + prepMinutes * 60 * 1000);
    }

    // Concurrency-safe atomic update
    const updatedOrder = await Order.findOneAndUpdate(
        { _id: orderId },
        {
            $set: {
                paymentStatus: isConfirmed ? "Verified" : "Rejected",
                paymentVerifiedAt: now,
                verifiedBy: adminEmail,
                paymentRejectionReason: resolvedReason,
                status: isConfirmed ? "Preparing" : "Payment Rejected",
                verificationAttempts: attempts,
                ...(isConfirmed ? {
                    estimatedPrepTime: prepMinutes,
                    estimatedReadyAt: readyAt
                } : {})
            }
        },
        { new: true }
    ).populate("userId", "fullName phoneNumber email");

    // Persistent in-app notification in MongoDB
    try {
        const customerId = updatedOrder.userId?._id || updatedOrder.userId;
        if (customerId) {
            await Notification.create({
                restaurantId: order.restaurantId,
                userId: customerId,
                orderId: updatedOrder._id,
                title: isConfirmed ? "Serveo: Payment Verified!" : "Serveo: Payment Not Confirmed",
                body: isConfirmed
                    ? `Order #${updatedOrder._id.toString().slice(-4)} payment confirmed. Food preparation started!`
                    : `We could not verify payment for Order #${updatedOrder._id.toString().slice(-4)}. Reason: ${resolvedReason}. Please check your transaction or submit verification again.`,
                type: isConfirmed ? "payment_verified" : "payment_rejected"
            });
        }
    } catch (notifErr) {
        console.error("In-app notification creation error:", notifErr.message);
    }

    // Optional background FCM dispatch if configured
    try {
        const customer = await User.findById(updatedOrder.userId);
        if (customer && customer.fcmToken) {
            const message = {
                notification: {
                    title: isConfirmed ? "Serveo: Payment Verified!" : "Serveo: Payment Not Confirmed",
                    body: isConfirmed
                        ? `Order #${updatedOrder._id.toString().slice(-4)} payment confirmed. Food preparation started!`
                        : `We could not verify payment for Order #${updatedOrder._id.toString().slice(-4)}. Reason: ${resolvedReason}.`,
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
        message: isConfirmed
            ? "Payment verified successfully. Order moved to preparation."
            : "Payment claim rejected.",
        order: updatedOrder
    };
};
