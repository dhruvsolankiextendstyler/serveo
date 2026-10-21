import mongoose from "mongoose";

const itemSchema = new mongoose.Schema(
    {
        itemName: {
            type: String,
            required: true,
            unique: true
        },
        itemPrice: {
            type: Number,
            required: true
        },
        category: {
            type: String,
            enum: ["Burgers", "Pizza", "Sandwiches", "Snacks", "Beverages", "Desserts", "Thali", "South Indian"],
            required: true
        },
        description: {
            type: String,
            required: false,
            default: ""
        },
        isAvailable: {
            type: Boolean,
            default: true
        }
    },
    {timestamps: true}
)

export const Item = mongoose.model("Item", itemSchema)
