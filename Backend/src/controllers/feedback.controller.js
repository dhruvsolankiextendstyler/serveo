import mongoose from "mongoose";
import { Feedback } from "../models/feedback.models.js";
import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";

function sanitizeText(str) {
    if (!str) return "";
    return str
        .trim()
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "") // Remove script tags and contents
        .replace(/<[^>]*>?/gm, "") // Remove any remaining HTML tags
        .trim()
        .slice(0, 500);
}

export const submitFeedbackController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;

    if (!uid && !email) {
        const error = new Error("Authentication required");
        error.status = 401;
        throw error;
    }

    let user = await User.findOne({ uid });
    if (!user && email) {
        user = await User.findOne({ email });
    }
    if (!user) {
        const error = new Error("User account not found");
        error.status = 401;
        throw error;
    }

    const { orderId, rating, comment, tags } = req.body;
    if (!orderId) {
        const error = new Error("Order ID is required");
        error.status = 400;
        throw error;
    }

    if (!mongoose.Types.ObjectId.isValid(orderId)) {
        const error = new Error("Invalid Order ID format");
        error.status = 400;
        throw error;
    }

    const parsedRating = Number(rating);
    if (!parsedRating || parsedRating < 1 || parsedRating > 5) {
        const error = new Error("Rating must be an integer between 1 and 5");
        error.status = 400;
        throw error;
    }

    const order = await Order.findById(orderId);
    if (!order) {
        const error = new Error("Order not found");
        error.status = 404;
        throw error;
    }

    // 1. Verify customer ownership
    if (order.userId.toString() !== user._id.toString()) {
        const error = new Error("You can only submit feedback for your own orders");
        error.status = 403;
        throw error;
    }

    // 2. Enforce completion eligibility: order must be completed or collected
    const eligibleStatuses = ["Completed", "Collected", "Ready"];
    if (!eligibleStatuses.includes(order.status)) {
        const error = new Error(`Feedback can only be submitted after food collection/completion (Current status: ${order.status})`);
        error.status = 400;
        throw error;
    }

    // 3. Prevent duplicate submissions
    const existing = await Feedback.findOne({ orderId: order._id });
    if (existing) {
        const error = new Error("Feedback has already been submitted for this order");
        error.status = 400;
        throw error;
    }

    const sanitizedComment = sanitizeText(comment);
    const sanitizedTags = Array.isArray(tags)
        ? tags.map(t => sanitizeText(t)).filter(t => t.length > 0)
        : [];

    const feedback = new Feedback({
        orderId: order._id,
        userId: user._id,
        customerName: user.fullName || "Customer",
        rating: Math.round(parsedRating),
        comment: sanitizedComment,
        tags: sanitizedTags,
    });

    await feedback.save();

    return {
        message: "Thank you for your feedback!",
        feedback: {
            id: feedback._id,
            orderId: feedback.orderId,
            rating: feedback.rating,
            comment: feedback.comment,
            tags: feedback.tags,
            createdAt: feedback.createdAt,
        }
    };
};

export const getOrderFeedbackController = async (req) => {
    const orderId = req.params?.orderId || req.query?.orderId;
    if (!orderId || !mongoose.Types.ObjectId.isValid(orderId)) {
        const error = new Error("Valid Order ID is required");
        error.status = 400;
        throw error;
    }

    const feedback = await Feedback.findOne({ orderId }).lean();
    return feedback;
};

export const getAdminFeedbackController = async () => {
    const feedbackList = await Feedback.find()
        .populate("orderId", "totalAmount orderItems status createdAt customerDetails")
        .sort({ createdAt: -1 })
        .limit(100)
        .lean();

    const count = feedbackList.length;
    const avgRating = count > 0
        ? (feedbackList.reduce((sum, f) => sum + (f.rating || 0), 0) / count).toFixed(1)
        : "0.0";

    return {
        count,
        averageRating: Number(avgRating),
        feedback: feedbackList.map(f => ({
            id: f._id,
            orderId: f.orderId?._id || f.orderId,
            rating: f.rating,
            comment: f.comment,
            tags: f.tags,
            customerName: f.customerName,
            createdAt: f.createdAt,
            orderTotal: f.orderId?.totalAmount || 0,
            orderStatus: f.orderId?.status || "Unknown",
        }))
    };
};
