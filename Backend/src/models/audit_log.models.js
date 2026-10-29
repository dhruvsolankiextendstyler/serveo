import mongoose from "mongoose";

const auditLogSchema = new mongoose.Schema(
  {
    restaurantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Restaurant",
      required: true,
      index: true,
    },
    actorUid: {
      type: String,
      default: "system",
    },
    actorEmail: {
      type: String,
      default: "system@serveo.app",
    },
    actorRole: {
      type: String,
      default: "system",
    },
    action: {
      type: String,
      required: true,
      trim: true,
    },
    target: {
      type: String,
      default: "",
    },
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  { timestamps: true }
);

auditLogSchema.index({ restaurantId: 1, timestamp: -1 });

export const AuditLog = mongoose.model("AuditLog", auditLogSchema);

