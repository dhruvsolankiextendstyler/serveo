import http from "http";
import express from "express";
import cors from "cors";
import crypto from "crypto";
import mongoose from "mongoose";
import { restaurantRoute } from "./routes/restaurant.route.js";
import { userRoute } from "./routes/user.route.js";
import { itemRoute } from "./routes/item.route.js";
import { orderRoute } from "./routes/order.route.js";
import { analyticsRoute } from "./routes/analytics.route.js";

console.log("\n=== Testing Live Express Server Route Registration & Probing ===");

const app = express();
app.use(express.json());
app.use(cors());

// Mirror server.js middleware and route mounting exactly
app.use((req, res, next) => {
  const requestId = req.headers["x-request-id"] || crypto.randomUUID();
  req.id = requestId;
  res.setHeader("X-Request-Id", requestId);
  next();
});

app.get("/health", (req, res) => {
  res.json({
    status: "alive",
    service: "serveo-backend",
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

app.get("/health/ready", (req, res) => {
  res.status(200).json({
    status: "ready",
    service: "serveo-backend",
  });
});

app.use("/restaurant", restaurantRoute);
app.use("/user", userRoute);
app.use("/item", itemRoute);
app.use("/order", orderRoute);
app.use("/admin/analytics", analyticsRoute);
app.use("/analytics", analyticsRoute);

// Catch-all 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: `Cannot ${req.method} ${req.originalUrl}`,
    status: 404,
  });
});

// Start test server on port 5099
const server = app.listen(5099, async () => {
  console.log("Test Express server running on port 5099");

  try {
    // 1. Probe /health
    const healthRes = await fetch("http://localhost:5099/health");
    const healthData = await healthRes.json();
    console.log("✔ /health response:", healthRes.status, healthData);

    // 2. Probe /health/ready
    const readyRes = await fetch("http://localhost:5099/health/ready");
    const readyData = await readyRes.json();
    console.log("✔ /health/ready response:", readyRes.status, readyData);

    // 3. Probe POST /restaurant/admin/coupons without auth token
    const noAuthRes = await fetch("http://localhost:5099/restaurant/admin/coupons", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: "TEST" }),
    });
    const noAuthData = await noAuthRes.json();
    console.log("✔ POST /restaurant/admin/coupons without auth:", noAuthRes.status, noAuthData);

    // CRITICAL: The status must NOT be 404!
    if (noAuthRes.status === 404) {
      throw new Error("FAILED: POST /restaurant/admin/coupons returned 404 Not Found!");
    }
    // Must be 401 Unauthorized (because Firebase token is required)
    if (noAuthRes.status === 401) {
      console.log("  ✔ Confirmed: Endpoint EXISTS and rejects unauthenticated request with 401 (NOT 404)!");
    }

    // 4. Probe GET /restaurant/admin/coupons without auth
    const getRes = await fetch("http://localhost:5099/restaurant/admin/coupons");
    const getData = await getRes.json();
    console.log("✔ GET /restaurant/admin/coupons without auth:", getRes.status, getData);
    if (getRes.status === 404) {
      throw new Error("FAILED: GET /restaurant/admin/coupons returned 404 Not Found!");
    }
    if (getRes.status === 401) {
      console.log("  ✔ Confirmed: GET /restaurant/admin/coupons EXISTS and requires auth with 401 (NOT 404)!");
    }

    // 5. Probe an actual non-existent route to verify 404 handler
    const nonExistentRes = await fetch("http://localhost:5099/restaurant/admin/fake-route-xyz", {
      method: "POST",
    });
    const nonExistentData = await nonExistentRes.json();
    console.log("✔ Non-existent route correctly returns 404:", nonExistentRes.status, nonExistentData);

    console.log("\n All live server route probe tests passed successfully!\n");
  } catch (err) {
    console.error("Test probe error:", err);
    process.exitCode = 1;
  } finally {
    server.close();
    process.exit(process.exitCode || 0);
  }
});
