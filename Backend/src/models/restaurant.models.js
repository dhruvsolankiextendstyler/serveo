import mongoose from "mongoose";

const loyaltyRewardSchema = new mongoose.Schema(
  {
    rewardId: { type: String, required: true },
    title: { type: String, required: true },
    description: { type: String, default: "" },
    pointsRequired: { type: Number, required: true, min: 1 },
    discountType: { type: String, enum: ["flat", "percentage"], default: "flat" },
    discountValue: { type: Number, required: true, min: 1 },
    maxDiscountAmount: { type: Number, default: null },
    minOrderValue: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  { _id: false }
);

const loyaltyProgramSchema = new mongoose.Schema(
  {
    isEnabled: { type: Boolean, default: true },
    pointsPerRupee: { type: Number, default: 0.1 }, // e.g. 1 point for every ₹10 spent
    minimumOrderValueForEarn: { type: Number, default: 50 },
    canEarnOnDiscountedOrders: { type: Boolean, default: false },
    rewards: {
      type: [loyaltyRewardSchema],
      default: () => [
        {
          rewardId: "rew_flat_25",
          title: "₹25 Off Your Order",
          description: "Redeem 100 points for a ₹25 discount",
          pointsRequired: 100,
          discountType: "flat",
          discountValue: 25,
          minOrderValue: 75,
          isActive: true,
        },
        {
          rewardId: "rew_flat_50",
          title: "₹50 Off Your Order",
          description: "Redeem 200 points for a ₹50 discount",
          pointsRequired: 200,
          discountType: "flat",
          discountValue: 50,
          minOrderValue: 150,
          isActive: true,
        },
        {
          rewardId: "rew_pct_15",
          title: "15% Off Your Order",
          description: "Redeem 150 points for 15% off (up to ₹60)",
          pointsRequired: 150,
          discountType: "percentage",
          discountValue: 15,
          maxDiscountAmount: 60,
          minOrderValue: 100,
          isActive: true,
        },
      ],
    },
  },
  { _id: false }
);

const referralProgramSchema = new mongoose.Schema(
  {
    isEnabled: { type: Boolean, default: true },
    referrerPoints: { type: Number, default: 50 },
    refereePoints: { type: Number, default: 25 },
    minOrderValueForConversion: { type: Number, default: 100 },
  },
  { _id: false }
);

const operatingHourSchema = new mongoose.Schema(
  {
    day: {
      type: String,
      enum: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: true,
    },
    openTime: {
      type: String,
      default: "09:00",
    },
    closeTime: {
      type: String,
      default: "22:00",
    },
  },
  { _id: false }
);

const staffMemberSchema = new mongoose.Schema(
  {
    uid: {
      type: String,
      default: "",
    },
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    name: {
      type: String,
      default: "",
      trim: true,
    },
    role: {
      type: String,
      enum: ["owner", "manager", "kitchen", "cashier", "viewer"],
      default: "manager",
    },
    invitedBy: {
      type: String,
      default: "system",
    },
    addedAt: {
      type: Date,
      default: Date.now,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { _id: true }
);

const subscriptionHistorySchema = new mongoose.Schema(
  {
    action: { type: String, required: true },
    fromPlan: { type: String, default: "" },
    toPlan: { type: String, default: "" },
    actor: { type: String, default: "system" },
    reason: { type: String, default: "" },
    timestamp: { type: Date, default: Date.now },
  },
  { _id: false }
);

const subscriptionSchema = new mongoose.Schema(
  {
    planId: {
      type: String,
      enum: ["starter", "growth", "premium"],
      default: "starter",
    },
    status: {
      type: String,
      enum: ["trial", "active", "past_due", "canceled", "expired"],
      default: "active",
    },
    startDate: {
      type: Date,
      default: Date.now,
    },
    endDate: {
      type: Date,
      default: null,
    },
    trialEndsAt: {
      type: Date,
      default: null,
    },
    gracePeriodDays: {
      type: Number,
      default: 7,
    },
    adminOverride: {
      type: Boolean,
      default: false,
    },
    customLimits: {
      maxActiveMenuItems: { type: Number, default: null },
      maxStaffAccounts: { type: Number, default: null },
      allowAdvancedAnalytics: { type: Boolean, default: null },
    },
    history: {
      type: [subscriptionHistorySchema],
      default: () => [
        {
          action: "INITIAL_PROVISION",
          fromPlan: "",
          toPlan: "starter",
          actor: "system",
          reason: "Initial restaurant onboarding",
          timestamp: new Date(),
        },
      ],
    },
  },
  { _id: false }
);

const restaurantSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      default: "Serveo",
    },
    slug: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      default: "default",
    },
    description: {
      type: String,
      default: "Fresh meals & quick snacks ready for counter pickup",
      trim: true,
    },
    logoUrl: {
      type: String,
      default: "",
    },
    bannerUrl: {
      type: String,
      default: "",
    },
    address: {
      street: { type: String, default: "" },
      city: { type: String, default: "" },
      state: { type: String, default: "" },
      postalCode: { type: String, default: "" },
      country: { type: String, default: "India" },
    },
    contact: {
      phone: { type: String, default: "" },
      email: { type: String, default: "" },
    },
    currency: {
      type: String,
      default: "INR",
      uppercase: true,
      trim: true,
    },
    currencySymbol: {
      type: String,
      default: "₹",
    },
    timezone: {
      type: String,
      default: "Asia/Kolkata",
    },
    operatingDays: {
      type: [String],
      default: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
    },
    openingTime: {
      type: String,
      default: "09:00",
    },
    closingTime: {
      type: String,
      default: "22:00",
    },
    schedule: {
      type: [operatingHourSchema],
      default: () => [
        { day: "Monday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
        { day: "Tuesday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
        { day: "Wednesday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
        { day: "Thursday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
        { day: "Friday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
        { day: "Saturday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
        { day: "Sunday", isOpen: true, openTime: "09:00", closeTime: "22:00" },
      ],
    },
    isOrderAcceptancePaused: {
      type: Boolean,
      default: false,
    },
    pauseReason: {
      type: String,
      default: "",
    },
    defaultEstimatedPrepTime: {
      type: Number,
      default: 20,
      min: 5,
      max: 120,
    },
    displayPreferences: {
      announcement: { type: String, default: "" },
      showPrepTime: { type: Boolean, default: true },
      showDietaryBadges: { type: Boolean, default: true },
    },
    adminUids: {
      type: [String],
      default: [],
    },
    adminEmails: {
      type: [String],
      default: ["admin123@ad.in"],
    },
    staff: {
      type: [staffMemberSchema],
      default: () => [
        {
          uid: "",
          email: "admin123@ad.in",
          name: "Primary Owner",
          role: "owner",
          invitedBy: "system",
          addedAt: new Date(),
          isActive: true,
        },
      ],
    },
    loyaltyProgram: {
      type: loyaltyProgramSchema,
      default: () => ({
        isEnabled: true,
        pointsPerRupee: 0.1,
        minimumOrderValueForEarn: 50,
        canEarnOnDiscountedOrders: false,
      }),
    },
    referralProgram: {
      type: referralProgramSchema,
      default: () => ({
        isEnabled: true,
        referrerPoints: 50,
        refereePoints: 25,
        minOrderValueForConversion: 100,
      }),
    },
    subscription: {
      type: subscriptionSchema,
      default: () => ({
        planId: "starter",
        status: "active",
        startDate: new Date(),
        endDate: null,
        gracePeriodDays: 7,
        adminOverride: false,
        history: [
          {
            action: "INITIAL_PROVISION",
            fromPlan: "",
            toPlan: "starter",
            actor: "system",
            reason: "Initial restaurant onboarding",
            timestamp: new Date(),
          },
        ],
      }),
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

restaurantSchema.index({ adminEmails: 1 });
restaurantSchema.index({ adminUids: 1 });
restaurantSchema.index({ "staff.email": 1 });
restaurantSchema.index({ "staff.uid": 1 });

export const Restaurant = mongoose.model("Restaurant", restaurantSchema);
