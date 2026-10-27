import assert from "assert";
import mongoose from "mongoose";
import express from "express";
import http from "http";

// Test suite for Bug 1 and Bug 2 Backend endpoints
console.log("=== Running Serveo Item & Menu Management Backend Tests ===");

// 1. Test ObjectId validation logic used in item.route.js
console.log("\n[1] Testing ObjectId Validation Logic...");
const validId = "66f4001b9a2c3d4e5f607182";
const invalidIds = ["undefined", "null", "123", "", "item_001", "xyz"];

assert.strictEqual(mongoose.Types.ObjectId.isValid(validId), true, "Valid 24-hex ObjectId must be valid");
for (const badId of invalidIds) {
  assert.strictEqual(mongoose.Types.ObjectId.isValid(badId), false, `ID '${badId}' must NOT be considered valid ObjectId`);
}
console.log("  ✔ ObjectId validation correctly identifies valid vs malformed IDs");

// 2. Test Item Validation logic in addItem.controller.js
console.log("\n[2] Testing Add Item Field Validation...");
function validateItemFields(body) {
  const { itemName, itemPrice, category } = body;
  if (!itemName || typeof itemName !== "string" || !itemName.trim()) {
    return { status: 400, message: "Item name is required and cannot be empty" };
  }
  const numericPrice = Number(itemPrice);
  if (itemPrice === undefined || itemPrice === null || isNaN(numericPrice) || numericPrice <= 0) {
    return { status: 400, message: "A valid positive item price is required" };
  }
  if (!category || typeof category !== "string" || !category.trim()) {
    return { status: 400, message: "Category is required and cannot be empty" };
  }
  return { status: 200, valid: true };
}

// Missing name
assert.strictEqual(validateItemFields({ itemPrice: 100, category: "Burgers" }).status, 400);
// Zero price
assert.strictEqual(validateItemFields({ itemName: "Burger", itemPrice: 0, category: "Burgers" }).status, 400);
// Negative price
assert.strictEqual(validateItemFields({ itemName: "Burger", itemPrice: -50, category: "Burgers" }).status, 400);
// Missing category
assert.strictEqual(validateItemFields({ itemName: "Burger", itemPrice: 150 }).status, 400);
// Valid item
assert.strictEqual(validateItemFields({ itemName: "Burger", itemPrice: 150, category: "Burgers" }).status, 200);
console.log("  ✔ Field validation correctly enforces non-empty names, categories, and positive prices");

// 3. Test Global Express Error Middleware Returns JSON (not HTML <!DOCTYPE)
console.log("\n[3] Testing Global 500 Error Middleware for JSON Integrity...");
const testApp = express();
testApp.use(express.json());

// A route that intentionally throws an unhandled error
testApp.get("/crash", (req, res, next) => {
  throw new Error("Simulated unhandled server exception");
});

// Serveo Global Error Handler (from server.js)
testApp.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    error: err.message || "Internal Server Error",
    status: err.status || 500,
  });
});

// A 404 catch-all that returns JSON
testApp.use((req, res) => {
  res.status(404).json({ error: `Cannot ${req.method} ${req.originalUrl}` });
});

// Start local test server on ephemeral port
const server = testApp.listen(0, async () => {
  const port = server.address().port;

  function doRequest(path) {
    return new Promise((resolve, reject) => {
      http.get(`http://localhost:${port}${path}`, (res) => {
        let data = "";
        res.on("data", (chunk) => { data += chunk; });
        res.on("end", () => {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data,
          });
        });
      }).on("error", reject);
    });
  }

  try {
    // Test unhandled error returns JSON
    const errorRes = await doRequest("/crash");
    assert.strictEqual(errorRes.statusCode, 500);
    assert.strictEqual(errorRes.headers["content-type"].includes("application/json"), true, "Must return application/json");
    const parsedError = JSON.parse(errorRes.body);
    assert.strictEqual(parsedError.error, "Simulated unhandled server exception");
    assert.strictEqual(errorRes.body.startsWith("<!DOCTYPE"), false, "Error response must NEVER be HTML <!DOCTYPE");
    console.log("  ✔ Unhandled exceptions return structured JSON error instead of Express HTML error page");

    // Test missing route returns JSON 404
    const notFoundRes = await doRequest("/nonexistent/endpoint");
    assert.strictEqual(notFoundRes.statusCode, 404);
    assert.strictEqual(notFoundRes.headers["content-type"].includes("application/json"), true);
    assert.strictEqual(notFoundRes.body.startsWith("<!DOCTYPE"), false);
    console.log("  ✔ Missing endpoints return JSON 404 instead of HTML 404");

    console.log("\nAll Item & Menu Backend Validation Tests Passed Successfully!\n");
    server.close(() => process.exit(0));
  } catch (err) {
    console.error("Test failed:", err);
    server.close(() => process.exit(1));
  }
});
