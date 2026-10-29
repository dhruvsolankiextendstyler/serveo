import "dotenv/config";
import express from "express";
import cors from "cors";
import crypto from "crypto";
import mongoose from "mongoose";
import { userRoute } from "./routes/user.route.js";
import { DBConnect } from "./utils/db_connect.js";
import { itemRoute } from "./routes/item.route.js";
import { orderRoute } from "./routes/order.route.js";
import { analyticsRoute } from "./routes/analytics.route.js";
import { restaurantRoute } from "./routes/restaurant.route.js";
import { renderPublicWebMenuController } from "./controllers/restaurant.controller.js";
import { initDefaultRestaurant } from "./utils/init_default_restaurant.js";
import { logger } from "./utils/logger.js";

const app = express();

app.use(express.json());
app.use(cors());

// Correlation / Request ID Middleware for production diagnostics
app.use((req, res, next) => {
  const requestId = req.headers["x-request-id"] || crypto.randomUUID();
  req.id = requestId;
  res.setHeader("X-Request-Id", requestId);
  next();
});

// Connect database and run safe, idempotent default restaurant migration
DBConnect().then(async () => {
  await initDefaultRestaurant();
}).catch(err => {
  logger.error("system", "DB Connection / Init Error", err);
});

// 🔹 Liveness check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "alive",
    service: "serveo-backend",
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    database: mongoose.connection.readyState === 1 ? "connected" : "connecting"
  });
});

// 🔹 Readiness check endpoint (checks database readiness without exposing secrets)
app.get("/health/ready", (req, res) => {
  const isDbReady = mongoose.connection.readyState === 1;
  const status = isDbReady ? 200 : 503;
  res.status(status).json({
    status: isDbReady ? "ready" : "not_ready",
    service: "serveo-backend",
    database: isDbReady ? "connected" : "disconnected",
    memoryUsageMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

// 🔹 Public Web Menu for browser QR scan (mobile & desktop)
app.get("/menu/:identifier", renderPublicWebMenuController);
app.get("/menu", (req, res) => {
  renderPublicWebMenuController({ params: { identifier: "default" }, get: req.get.bind(req), protocol: req.protocol }, res);
});

// 🔹 API Routes
app.use('/restaurant', restaurantRoute);
app.use('/user', userRoute);
app.use('/item', itemRoute);
app.use('/order', orderRoute);
app.use('/admin/analytics', analyticsRoute);
app.use('/analytics', analyticsRoute);

// Catch-all 404 handler: return structured JSON error instead of Express default HTML page
app.use((req, res) => {
  res.status(404).json({
    error: `Cannot ${req.method} ${req.originalUrl}`,
    status: 404,
  });
});

// Global error handler: ensure JSON is ALWAYS returned instead of Express default HTML error page
app.use((err, req, res, next) => {
  logger.error("api", "Unhandled server error", err, {
    requestId: req.id,
    method: req.method,
    url: req.originalUrl,
  });
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    error: err.message || "Internal server error",
    status,
    requestId: req.id,
  });
});

app.listen(process.env.PORT || 5000, () => {
  console.log("Server Started");
});
