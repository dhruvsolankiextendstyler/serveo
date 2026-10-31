import mongoose from "mongoose";

const campaignSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Restaurant",
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    bannerUrl: {
      type: String,
      default: "",
    },
    campaignType: {
      type: String,
      enum: ["weekend", "limited_time", "festival", "item_special", "category_offer", "general"],
      default: "general",
    },
    couponCode: {
      type: String,
      default: "",
      uppercase: true,
      trim: true,
    },
    startDate: {
      type: Date,
      default: Date.now,
    },
    endDate: {
      type: Date,
      required: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    termsAndConditions: {
      type: String,
      default: "Valid for a limited time at participating restaurant. Subject to availability.",
      trim: true,
    },
    eligibleCategories: {
      type: [String],
      default: [],
    },
    eligibleItems: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "Item",
      default: [],
    },
    clickCount: {
      type: Number,
      default: 0,
    },
    viewCount: {
      type: Number,
      default: 0,
    },
    createdBy: {
      type: String,
      default: "admin",
    },
  },
  { timestamps: true }
);

campaignSchema.index({ restaurantId: 1, isActive: 1, startDate: 1, endDate: 1 });

export const Campaign = mongoose.model("Campaign", campaignSchema);
