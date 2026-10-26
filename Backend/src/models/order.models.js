import mongoose from "mongoose";

const orderSchema = new mongoose.Schema(
    {
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true
        },
        customerDetails: {
            fullName: {
                type: String,
                default: ""
            },
            phoneNumber: {
                type: String,
                default: ""
            },
            email: {
                type: String,
                default: ""
            }
        },
        orderItems: [
            {
                itemId: {
                    type: mongoose.Schema.Types.ObjectId,
                    ref: 'Item',
                    required: true,
                },
                itemName: {
                    type: String,
                    required: true
                },
                itemPrice: {
                    type: Number,
                    required: true
                },
                quantity: {
                    type: Number,
                    required: true
                }
            }
        ],
        totalAmount: {
            type: Number,
            default: 0
        },
        status: {
            type: String,
            enum: ["Processing", "Preparing", "Completed", "Collected", "Pending Verification", "Payment Rejected", "Cancelled"],
            required: true,
            default: "Processing"
        },
        paymentMethod: {
            type: String,
            enum: ["UPI", "COD", "Card"],
            default: "COD"
        },
        paymentStatus: {
            type: String,
            enum: ["Pending", "Awaiting Verification", "Verified", "Rejected"],
            default: "Pending"
        },
        paymentClaimedAt: {
            type: Date,
            default: null
        },
        paymentVerifiedAt: {
            type: Date,
            default: null
        },
        verifiedBy: {
            type: String,
            default: null
        }
    },
    {timestamps:true}
)

orderSchema.pre("save", function(){
    var total = 0
    this.orderItems.forEach(item => {
        total += item.itemPrice * item.quantity
    });
    this.totalAmount = total
})

// Hot query paths: per-user order lists and the KDS createdAt sort
orderSchema.index({ userId: 1 })
orderSchema.index({ createdAt: 1 })
orderSchema.index({ paymentStatus: 1 })

export const Order = mongoose.model("Order", orderSchema)