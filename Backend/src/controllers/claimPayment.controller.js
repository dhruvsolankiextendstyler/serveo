import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { Notification } from "../models/notification.models.js";

export const claimPaymentController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;

    if (!uid && !email) {
        const error = new Error("Authentication required");
        error.status = 401;
        throw error;
    }

    let user = await User.findOne({ uid: uid });
    if (!user && email) {
        user = await User.findOne({ email: email });
    }
    if (!user) {
        const error = new Error("User account not found");
        error.status = 401;
        throw error;
    }

    const { orderId } = req.body;
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

    // 1. Verify customer ownership of the order
    if (order.userId.toString() !== user._id.toString()) {
        const error = new Error("Unauthorized to claim payment for this order");
        error.status = 403;
        throw error;
    }

    // 2. COD and non-UPI orders must not receive UPI verification
    if (order.paymentMethod && order.paymentMethod.toUpperCase() !== "UPI") {
        const error = new Error(`Payment verification is not applicable to ${order.paymentMethod} orders`);
        error.status = 400;
        throw error;
    }

    // 3. Prevent resubmission if order is already paid/verified
    if (order.paymentStatus === "Verified") {
        return {
            message: "Order payment has already been verified",
            order: order
        };
    }

    // 4. Ineligible terminal states
    if (order.status === "Cancelled") {
        const error = new Error("Cannot submit payment verification for a cancelled order");
        error.status = 400;
        throw error;
    }
    if (order.status === "Collected" || order.status === "Completed") {
        const error = new Error("Cannot submit payment verification for an already completed order");
        error.status = 400;
        throw error;
    }

    // 5. Prevent duplicate active verification requests
    if (order.paymentStatus === "Awaiting Verification") {
        const error = new Error("Payment verification is already pending store review");
        error.status = 400;
        throw error;
    }

    const now = new Date();
    const previousAttempts = Array.isArray(order.verificationAttempts) ? order.verificationAttempts : [];
    const attemptNumber = previousAttempts.length + 1;

    const newAttempt = {
        attemptNumber,
        submittedAt: now,
        status: "Pending",
        reviewedAt: null,
        reviewedBy: null,
        rejectionReason: null
    };

    // Concurrency-safe atomic update
    const updatedOrder = await Order.findOneAndUpdate(
        {
            _id: orderId,
            paymentStatus: { $ne: "Verified" },
            status: { $nin: ["Cancelled", "Collected", "Completed"] }
        },
        {
            $set: {
                paymentStatus: "Awaiting Verification",
                paymentClaimedAt: now,
                status: "Pending Verification"
            },
            $push: {
                verificationAttempts: newAttempt
            }
        },
        { new: true }
    );

    if (!updatedOrder) {
        const error = new Error("Order state could not be updated. Please try again.");
        error.status = 409;
        throw error;
    }

    // Record persistent customer in-app notification
    try {
        await Notification.create({
            userId: user._id,
            orderId: updatedOrder._id,
            title: attemptNumber > 1 ? "Payment Verification Resubmitted" : "Payment Verification Submitted",
            body: `Verification request (Attempt #${attemptNumber}) submitted for Order #${updatedOrder._id.toString().slice(-4)}. Store admin is reviewing your payment.`,
            type: "payment_pending"
        });
    } catch (notifErr) {
        console.error("Notification creation error:", notifErr.message);
    }

    return {
        message: attemptNumber > 1
            ? "Payment verification request resubmitted. Awaiting store verification."
            : "Payment claim submitted. Awaiting store verification.",
        order: updatedOrder
    };
};
