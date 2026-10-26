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
        },
        imageUrl: {
            type: String,
            required: false,
            default: ""
        },
        isVeg: {
            type: Boolean,
            default: true
        },
        dietary: {
            type: String,
            enum: ["Veg", "Non-Veg", "Vegan", ""],
            default: "Veg"
        }
    },
    {timestamps: true}
)

export const Item = mongoose.model("Item", itemSchema)
