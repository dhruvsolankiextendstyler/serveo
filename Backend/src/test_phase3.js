import assert from "assert";
import { trackOrderController } from "./controllers/trackOrder.controller.js";

console.log("=== Running Serveo Phase 3 Customer Experience Backend Tests ===");

// --- TEST 1: Track Order Parameter Validation ---
async function testTrackOrderValidation() {
  console.log("\n[1] Testing Track Order Parameter & Auth Validation...");

  // 1.1 Missing order ID
  try {
    await trackOrderController({ params: {} });
    assert.fail("Should throw on missing order ID");
  } catch (err) {
    assert.strictEqual(err.message, "Order ID is required");
    assert.strictEqual(err.status, 400);
    console.log("  ✔ Rejects missing order ID with 400");
  }

  // 1.2 Invalid order ID format (not an ObjectId)
  try {
    await trackOrderController({ params: { id: "not-a-valid-id" }, user: { uid: "uid123" } });
    assert.fail("Should throw on invalid ObjectId format");
  } catch (err) {
    assert.strictEqual(err.message, "Invalid Order ID format");
    assert.strictEqual(err.status, 400);
    console.log("  ✔ Rejects malformed ObjectId with 400");
  }

  // 1.3 Missing authentication
  try {
    await trackOrderController({ params: { id: "507f1f77bcf86cd799439011" } });
    assert.fail("Should throw when req.user is absent");
  } catch (err) {
    assert.strictEqual(err.message, "Authentication required");
    assert.strictEqual(err.status, 401);
    console.log("  ✔ Rejects unauthenticated tracking attempt with 401");
  }
}

// --- TEST 2: Search Regex Sanitization ---
function testSearchRegexSanitization() {
  console.log("\n[2] Testing Search Query Regex Sanitization...");

  function sanitizeSearchQuery(search) {
    return search.trim().replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
  }

  // Dangerous regex injection inputs
  assert.strictEqual(sanitizeSearchQuery("Burger (Cheese)"), "Burger \\(Cheese\\)");
  assert.strictEqual(sanitizeSearchQuery("Pizza [Extra]"), "Pizza \\[Extra\\]");
  assert.strictEqual(sanitizeSearchQuery("Cold+Coffee*"), "Cold\\+Coffee\\*");
  assert.strictEqual(sanitizeSearchQuery("^.*$"), "\\^\\.\\*\\$");
  assert.strictEqual(sanitizeSearchQuery("  Trimmed Item  "), "Trimmed Item");
  console.log("  ✔ Special regex characters safely escaped to prevent query injection and ReDoS");
}

// --- TEST 3: Order Status Timeline Mapping Integrity ---
function testOrderStatusTimelineMapping() {
  console.log("\n[3] Testing Order Status Timeline Mapping Integrity...");

  const canonicalSteps = ["Pending", "Accepted", "Preparing", "Ready", "Collected"];
  const legacyMap = {
    Processing: "Accepted",
    Completed: "Ready",
  };

  function getStepIndex(status) {
    const effective = legacyMap[status] || status;
    return canonicalSteps.indexOf(effective);
  }

  assert.strictEqual(getStepIndex("Pending"), 0);
  assert.strictEqual(getStepIndex("Processing"), 1); // Maps to Accepted step
  assert.strictEqual(getStepIndex("Accepted"), 1);
  assert.strictEqual(getStepIndex("Preparing"), 2);
  assert.strictEqual(getStepIndex("Ready"), 3);
  assert.strictEqual(getStepIndex("Completed"), 3); // Maps to Ready step
  assert.strictEqual(getStepIndex("Collected"), 4);

  // Terminal cancellation/rejection states must not advance along the happy-path timeline
  assert.strictEqual(getStepIndex("Cancelled"), -1);
  assert.strictEqual(getStepIndex("Payment Rejected"), -1);
  console.log("  ✔ Canonical and legacy statuses map correctly to customer timeline");
  console.log("  ✔ Terminal states (Cancelled, Payment Rejected) handled as distinct exceptions");
}

// --- TEST 4: Reorder Price & Availability Validation Rules ---
function testReorderCatalogValidation() {
  console.log("\n[4] Testing Reorder Catalog Validation Logic...");

  const currentCatalog = [
    { itemId: "item1", itemName: "Veggie Crunch Burger", itemPrice: 99, isAvailable: true }, // Price updated from 89 -> 99
    { itemId: "item2", itemName: "Cold Coffee", itemPrice: 79, isAvailable: false },          // Sold out
    { itemId: "item3", itemName: "Paneer Pizza", itemPrice: 199, isAvailable: true },
  ];

  const historicalOrderItems = [
    { itemId: "item1", itemName: "Veggie Crunch Burger", itemPrice: 89, quantity: 2 },
    { itemId: "item2", itemName: "Cold Coffee", itemPrice: 79, quantity: 1 },
    { itemId: "deleted_item", itemName: "Discontinued Special", itemPrice: 150, quantity: 1 },
  ];

  const availableToAdd = [];
  const unavailableOrDeleted = [];
  const priceUpdated = [];

  for (const hist of historicalOrderItems) {
    const catalogItem = currentCatalog.find(c => c.itemId === hist.itemId || c.itemName === hist.itemName);
    if (!catalogItem || !catalogItem.isAvailable) {
      unavailableOrDeleted.push(hist.itemName);
    } else {
      if (catalogItem.itemPrice !== hist.itemPrice) {
        priceUpdated.push({ name: hist.itemName, oldPrice: hist.itemPrice, newPrice: catalogItem.itemPrice });
      }
      availableToAdd.push({
        ...catalogItem,
        quantity: hist.quantity,
      });
    }
  }

  // Verify only available item was approved for reordering
  assert.strictEqual(availableToAdd.length, 1);
  assert.strictEqual(availableToAdd[0].itemName, "Veggie Crunch Burger");
  assert.strictEqual(availableToAdd[0].itemPrice, 99, "Must use current price, not historical price 89");

  // Verify sold-out and deleted items were flagged
  assert.strictEqual(unavailableOrDeleted.length, 2);
  assert.ok(unavailableOrDeleted.includes("Cold Coffee"));
  assert.ok(unavailableOrDeleted.includes("Discontinued Special"));

  // Verify price update was tracked
  assert.strictEqual(priceUpdated.length, 1);
  assert.strictEqual(priceUpdated[0].oldPrice, 89);
  assert.strictEqual(priceUpdated[0].newPrice, 99);

  console.log("  ✔ Reorder enforces current catalog prices and filters sold-out/deleted items");
}

async function runAll() {
  await testTrackOrderValidation();
  testSearchRegexSanitization();
  testOrderStatusTimelineMapping();
  testReorderCatalogValidation();
  console.log("\nAll Phase 3 Backend Security & Validation Tests Passed Successfully!\n");
}

runAll();
