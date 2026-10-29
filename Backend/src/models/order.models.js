import mongoose from "mongoose";

const orderSchema = new mongoose.Schema(
    {
        restaurantId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Restaurant',
            index: true,
            required: false // Optional in schema for backward compatibility, backfilled automatically
        },
        idempotencyKey: {
            type: String,
            sparse: true,
            index: true,
            trim: true,
        },
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
                },
                selectedCustomizations: [
                    {
                        customizationName: {
                            type: String,
                            default: ""
                        },
                        optionName: {
                            type: String,
                            default: ""
                        },
                        price: {
                            type: Number,
                            default: 0
                        }
                    }
                ]
            }
        ],
        totalAmount: {
            type: Number,
            default: 0
        },
        status: {
            type: String,
            enum: ["Pending", "Processing", "Accepted", "Preparing", "Ready", "Completed", "Collected", "Pending Verification", "Payment Rejected", "Cancelled"],
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
        },
        paymentRejectionReason: {
            type: String,
            default: null
        },
        verificationAttempts: [
            {
                attemptNumber: {
                    type: Number,
                    required: true
                },
                submittedAt: {
                    type: Date,
                    required: true
                },
                status: {
                    type: String,
                    enum: ["Pending", "Verified", "Rejected"],
                    default: "Pending"
                },
                reviewedAt: {
                    type: Date,
                    default: null
                },
                reviewedBy: {
                    type: String,
                    default: null
                },
                rejectionReason: {
                    type: String,
                    default: null
                }
            }
        ],
        estimatedPrepTime: {
            type: Number,
            default: null
        },
        estimatedReadyAt: {
            type: Date,
            default: null
        }
    },
    {timestamps:true}
)

orderSchema.pre("save", function(){
    var total = 0
    this.orderItems.forEach(item => {
        let itemUnitCost = Number(item.itemPrice) || 0;
        if (Array.isArray(item.selectedCustomizations)) {
            item.selectedCustomizations.forEach(c => {
                itemUnitCost += (Number(c.price) || 0);
            });
        }
        total += itemUnitCost * (Number(item.quantity) || 1);
    });
    this.totalAmount = total
})

// Hot query paths: per-user order lists and the KDS createdAt sort
orderSchema.index({ userId: 1 })
orderSchema.index({ createdAt: 1 })
orderSchema.index({ paymentStatus: 1 })
orderSchema.index({ restaurantId: 1, createdAt: 1 })
orderSchema.index({ restaurantId: 1, status: 1, paymentStatus: 1 })
// Analytics aggregation index for high performance date-range and revenue-status matching
orderSchema.index({ restaurantId: 1, createdAt: 1, status: 1, paymentStatus: 1, paymentMethod: 1 })
orderSchema.index({ createdAt: 1, status: 1, paymentStatus: 1, paymentMethod: 1 })

export const Order = mongoose.model("Order", orderSchema)
