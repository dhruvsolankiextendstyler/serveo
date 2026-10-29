import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { Notification } from "../models/notification.models.js";
import { admin } from "../utils/firebase_app.js";

export const updateStatusController = async (req) => {
    const { id, newStatus, estimatedPrepTime } = req.body;
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

    // Tenant isolation verification: Admin cannot update orders belonging to another restaurant
    if (req.restaurantId && order.restaurantId && order.restaurantId.toString() !== req.restaurantId.toString()) {
        const error = new Error("Unauthorized to update status of an order from another restaurant");
        error.status = 403;
        throw error;
    }

    // Role-based status transition enforcement
    if (req.staffRole) {
        if (req.staffRole === "viewer") {
            const error = new Error("Read-only viewer account cannot update order status");
            error.status = 403;
            error.code = "FORBIDDEN_ROLE";
            throw error;
        }
        if (req.staffRole === "cashier") {
            const error = new Error("Cashier accounts are restricted to payment verification and collection");
            error.status = 403;
            error.code = "FORBIDDEN_ROLE";
            throw error;
        }
        if (req.staffRole === "kitchen") {
            const kitchenAllowed = ["Accepted", "Preparing", "Ready", "Completed"];
            if (!kitchenAllowed.includes(newStatus)) {
                const error = new Error(`Kitchen staff may only transition orders to: ${kitchenAllowed.join(', ')}`);
                error.status = 403;
                error.code = "FORBIDDEN_ROLE";
                throw error;
            }
        }
    }

    // Do not allow transitioning a rejected payment order into kitchen preparation
    if (order.paymentStatus === "Rejected" && (newStatus === "Preparing" || newStatus === "Completed" || newStatus === "Ready")) {
        throw new Error("Cannot transition order with rejected payment to preparation");
    }

    order.status = newStatus;

    if (estimatedPrepTime !== undefined && Number(estimatedPrepTime) > 0) {
        order.estimatedPrepTime = Number(estimatedPrepTime);
        order.estimatedReadyAt = new Date(Date.now() + Number(estimatedPrepTime) * 60 * 1000);
    }

    await order.save();

    // Map status change to in-app customer notification
    const shortId = order._id.toString().slice(-4);
    let notifTitle = null;
    let notifBody = null;
    let notifType = "order_accepted";

    switch (newStatus) {
        case "Accepted":
            notifTitle = "Serveo: Order Accepted!";
            notifBody = `Order #${shortId} has been accepted by the kitchen. Preparation will begin shortly.`;
            notifType = "order_accepted";
            break;
        case "Preparing":
            notifTitle = "Serveo: Food Preparation Started!";
            notifBody = `The kitchen has started preparing Order #${shortId}. ${order.estimatedPrepTime ? `Estimated time: ~${order.estimatedPrepTime} mins.` : ''}`;
            notifType = "order_preparing";
            break;
        case "Ready":
        case "Completed":
            notifTitle = "Serveo: Food is Ready!";
            notifBody = `Order #${shortId} is hot and ready for pickup at the counter!`;
            notifType = "order_ready";
            break;
        case "Collected":
            notifTitle = "Serveo: Order Collected";
            notifBody = `Order #${shortId} was collected. Enjoy your meal! Please consider leaving feedback.`;
            notifType = "order_collected";
            break;
        case "Cancelled":
            notifTitle = "Serveo: Order Cancelled";
            notifBody = `Order #${shortId} was cancelled by restaurant staff. Please contact the counter for assistance.`;
            notifType = "order_cancelled";
            break;
    }

    if (notifTitle) {
        try {
            await Notification.create({
                restaurantId: order.restaurantId,
                userId: order.userId,
                orderId: order._id,
                title: notifTitle,
                body: notifBody,
                type: notifType,
            });
        } catch (err) {
            console.error("In-app notification creation error:", err.message);
        }
    }

    // FCM Push Notification dispatch
    if (newStatus === "Completed" || newStatus === "Ready" || newStatus === "Preparing") {
        try {
            const user = await User.findById(order.userId);
            if (user && user.fcmToken) {
                const message = {
                    notification: {
                        title: notifTitle || "Serveo Order Update",
                        body: notifBody || `Order #${shortId} status is now ${newStatus}.`,
                    },
                    token: user.fcmToken,
                };
                admin.messaging().send(message)
                    .then(() => console.log("✅ FCM sent to:", user.email))
                    .catch((fcmError) => console.error("❌ FCM Error Details:", fcmError.message));
            }
        } catch (_) {}
    }

    return "Status Changed";
};
