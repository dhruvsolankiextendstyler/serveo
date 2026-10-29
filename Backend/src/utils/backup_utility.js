/**
 * Serveo MongoDB Backup & Integrity Verification Utility
 *
 * Provides logical backup verification, document count sanity checks,
 * and collection consistency inspection for production disaster readiness.
 */
import mongoose from "mongoose";
import fs from "fs";
import path from "path";
import { Restaurant } from "../models/restaurant.models.js";
import { Item } from "../models/item.models.js";
import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { Notification } from "../models/notification.models.js";
import { Feedback } from "../models/feedback.models.js";
import { AuditLog } from "../models/audit_log.models.js";
import { logger } from "./logger.js";

const COLLECTIONS = [
  { name: "restaurants", model: Restaurant },
  { name: "items", model: Item },
  { name: "orders", model: Order },
  { name: "users", model: User },
  { name: "notifications", model: Notification },
  { name: "feedbacks", model: Feedback },
  { name: "auditlogs", model: AuditLog },
];

/**
 * Inspects database readiness and generates collection health metrics.
 */
export async function verifyDatabaseReadiness() {
  const isConnected = mongoose.connection.readyState === 1;
  const metrics = {
    connected: isConnected,
    databaseName: mongoose.connection.name || "serveo",
    collections: {},
    totalDocuments: 0,
    timestamp: new Date().toISOString(),
  };

  if (!isConnected) {
    return metrics;
  }

  for (const { name, model } of COLLECTIONS) {
    try {
      const count = await model.countDocuments();
      metrics.collections[name] = {
        count,
        healthy: true,
      };
      metrics.totalDocuments += count;
    } catch (err) {
      metrics.collections[name] = {
        count: 0,
        healthy: false,
        error: err.message,
      };
    }
  }

  return metrics;
}

/**
 * Performs a safe, non-destructive logical JSON export of a restaurant's records.
 * Can be used for tenant-specific backup or offline compliance archiving.
 */
export async function exportTenantSnapshot(restaurantId, outputDir = "./backups") {
  if (!restaurantId) {
    throw new Error("restaurantId is required for tenant snapshot export");
  }

  const query = { restaurantId };
  const snapshot = {
    metadata: {
      restaurantId: restaurantId.toString(),
      exportedAt: new Date().toISOString(),
      version: "1.0",
    },
    restaurant: await Restaurant.findById(restaurantId).lean(),
    items: await Item.find(query).lean(),
    orders: await Order.find(query).lean(),
    notifications: await Notification.find(query).lean(),
    feedback: await Feedback.find(query).lean(),
    auditLogs: await AuditLog.find(query).lean(),
  };

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const filename = `tenant_${restaurantId}_${Date.now()}.json`;
  const filePath = path.join(outputDir, filename);
  fs.writeFileSync(filePath, JSON.stringify(snapshot, null, 2));

  logger.info("system", "Tenant snapshot export completed", {
    restaurantId: restaurantId.toString(),
    filePath,
    itemsCount: snapshot.items.length,
    ordersCount: snapshot.orders.length,
  });

  return {
    filePath,
    counts: {
      items: snapshot.items.length,
      orders: snapshot.orders.length,
      auditLogs: snapshot.auditLogs.length,
    },
  };
}

