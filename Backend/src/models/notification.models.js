import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
    {
        restaurantId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Restaurant',
            index: true,
            required: false
        },
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
            index: true
        },
        orderId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Order',
            required: false,
            default: null,
            index: true
        },
        title: {
            type: String,
            required: true
        },
        body: {
            type: String,
            required: true
        },
        type: {
            type: String,
            enum: [
                "order_placed",
                "order_accepted",
                "order_preparing",
                "order_ready",
                "order_collected",
                "order_cancelled",
                "payment_pending",
                "payment_verified",
                "payment_rejected",
                "promotion",
                "coupon_expiring",
                "reward_unlocked",
                "points_credited",
                "referral_reward",
                "special_offer"
            ],
            default: "order_placed"
        },
        metadata: {
            type: mongoose.Schema.Types.Mixed,
            default: {}
        },
        isRead: {
            type: Boolean,
            default: false
        }
    },
    { timestamps: true }
);

notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ restaurantId: 1, createdAt: -1 });

export const Notification = mongoose.model("Notification", notificationSchema);
