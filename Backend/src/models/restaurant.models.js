import mongoose from "mongoose";

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
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

restaurantSchema.index({ adminEmails: 1 });
restaurantSchema.index({ adminUids: 1 });

export const Restaurant = mongoose.model("Restaurant", restaurantSchema);
