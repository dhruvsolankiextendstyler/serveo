import mongoose from "mongoose";

const feedbackSchema = new mongoose.Schema(
    {
        restaurantId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Restaurant',
            index: true,
            required: false
        },
        orderId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Order',
            required: true,
            unique: true
        },
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
            index: true
        },
        customerName: {
            type: String,
            default: "Customer"
        },
        rating: {
            type: Number,
            required: true,
            min: 1,
            max: 5
        },
        comment: {
            type: String,
            default: "",
            maxlength: 500
        },
        tags: [
            {
                type: String
            }
        ]
    },
    { timestamps: true }
);

feedbackSchema.index({ createdAt: -1 });
feedbackSchema.index({ restaurantId: 1, createdAt: -1 });

export const Feedback = mongoose.model("Feedback", feedbackSchema);
