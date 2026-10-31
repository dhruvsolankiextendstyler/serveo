import mongoose from "mongoose";

const loyaltyAccountSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Restaurant",
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    currentBalance: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalEarned: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalRedeemed: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  { timestamps: true }
);

loyaltyAccountSchema.index({ restaurantId: 1, userId: 1 }, { unique: true });

export const LoyaltyAccount = mongoose.model("LoyaltyAccount", loyaltyAccountSchema);

const loyaltyLedgerSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Restaurant",
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Order",
      default: null,
      index: true,
    },
    transactionType: {
      type: String,
      enum: ["EARN", "REDEEM", "CANCEL_REVERSAL", "REFUND_REVERSAL", "BONUS_REFERRAL", "MANUAL_ADJUSTMENT"],
      required: true,
    },
    points: {
      type: Number,
      required: true, // Positive for addition, negative for deduction
    },
    balanceAfter: {
      type: Number,
      required: true,
      min: 0,
    },
    description: {
      type: String,
      default: "",
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  { timestamps: true }
);

loyaltyLedgerSchema.index({ restaurantId: 1, userId: 1, createdAt: -1 });
loyaltyLedgerSchema.index({ restaurantId: 1, orderId: 1, transactionType: 1 });

export const LoyaltyLedger = mongoose.model("LoyaltyLedger", loyaltyLedgerSchema);
