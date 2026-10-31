import mongoose from "mongoose";

const referralCodeSchema = new mongoose.Schema(
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
    code: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    totalReferred: {
      type: Number,
      default: 0,
    },
    successfulConversions: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

referralCodeSchema.index({ restaurantId: 1, userId: 1 }, { unique: true });
referralCodeSchema.index({ restaurantId: 1, code: 1 }, { unique: true });

export const ReferralCode = mongoose.model("ReferralCode", referralCodeSchema);

const referralRecordSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Restaurant",
      required: true,
      index: true,
    },
    referrerUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    refereeUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    referralCode: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ["pending", "converted", "cancelled"],
      default: "pending",
      index: true,
    },
    qualifyingOrderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Order",
      default: null,
    },
    rewardGranted: {
      type: Boolean,
      default: false,
    },
    rewardGrantedAt: {
      type: Date,
      default: null,
    },
    referrerPointsAwarded: {
      type: Number,
      default: 0,
    },
    refereePointsAwarded: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

// One referee can only be referred once per restaurant
referralRecordSchema.index({ restaurantId: 1, refereeUserId: 1 }, { unique: true });

export const ReferralRecord = mongoose.model("ReferralRecord", referralRecordSchema);
