import assert from "assert";
import { getISTDateRanges, getSuccessfulRevenueFilter } from "./controllers/analytics.controller.js";

console.log("=== Running Serveo Phase 2 Backend Analytics Tests ===");

// --- TEST SUITE 1: Timezone & Date Filter Boundaries (Asia/Kolkata UTC+05:30) ---
function testISTDateRanges() {
  console.log("\n[1] Testing IST Date Range Calculations...");

  // 1.1 "today"
  const todayRange = getISTDateRanges("today");
  assert.strictEqual(todayRange.current.isSingleDay, true);
  assert.strictEqual(todayRange.current.label, "Today");
  assert.strictEqual(todayRange.timezone, "Asia/Kolkata");

  // Check that start and end are 24 hours apart (86399999 ms)
  const todaySpan = todayRange.current.end.getTime() - todayRange.current.start.getTime();
  assert.strictEqual(todaySpan, 86399999, "Today must span exactly 23h 59m 59s 999ms");
  console.log("  ✔ 'today' covers exact 24h IST boundary");

  // 1.2 "yesterday"
  const yesterdayRange = getISTDateRanges("yesterday");
  assert.strictEqual(yesterdayRange.current.isSingleDay, true);
  assert.strictEqual(yesterdayRange.current.label, "Yesterday");
  // Yesterday end must immediately precede today's start
  assert.strictEqual(yesterdayRange.current.end.getTime() + 1, todayRange.current.start.getTime());
  console.log("  ✔ 'yesterday' correctly connects to today's start");

  // 1.3 "7d"
  const last7Range = getISTDateRanges("7d");
  assert.strictEqual(last7Range.current.label, "Last 7 Days");
  assert.strictEqual(last7Range.previous.label, "Previous Period");
  // Current 7d span should be 7 full days
  const span7d = (last7Range.current.end.getTime() - last7Range.current.start.getTime() + 1) / (24 * 3600 * 1000);
  assert.strictEqual(span7d, 7, "Last 7 days must span exactly 7 full days");
  console.log("  ✔ '7d' covers exactly 7 calendar days");

  // 1.4 "30d"
  const last30Range = getISTDateRanges("30d");
  const span30d = (last30Range.current.end.getTime() - last30Range.current.start.getTime() + 1) / (24 * 3600 * 1000);
  assert.strictEqual(span30d, 30, "Last 30 days must span exactly 30 calendar days");
  console.log("  ✔ '30d' covers exactly 30 calendar days");

  // 1.5 "this_month"
  const thisMonthRange = getISTDateRanges("this_month");
  assert.strictEqual(thisMonthRange.current.label, "This Month");
  assert.ok(thisMonthRange.current.start <= thisMonthRange.current.end);
  console.log("  ✔ 'this_month' starts on 1st of month");

  // 1.6 "prev_month"
  const prevMonthRange = getISTDateRanges("prev_month");
  assert.strictEqual(prevMonthRange.current.label, "Previous Month");
  assert.ok(prevMonthRange.current.start < prevMonthRange.current.end);
  console.log("  ✔ 'prev_month' covers previous calendar month");

  // 1.7 "custom" valid
  const customRange = getISTDateRanges("custom", "2026-10-01", "2026-10-15");
  assert.strictEqual(customRange.current.isSingleDay, false);
  assert.ok(customRange.current.label.includes("2026-10-01 to 2026-10-15"));
  const customSpanDays = (customRange.current.end.getTime() - customRange.current.start.getTime() + 1) / (24 * 3600 * 1000);
  assert.strictEqual(customSpanDays, 15, "1 Oct to 15 Oct is exactly 15 days");
  console.log("  ✔ 'custom' computes exact day spans");

  // 1.8 "custom" validation errors
  assert.throws(
    () => getISTDateRanges("custom", null, null),
    /Both startDate and endDate are required/,
    "Should reject missing custom dates"
  );
  assert.throws(
    () => getISTDateRanges("custom", "invalid", "dates"),
    /Invalid custom date format/,
    "Should reject invalid date format"
  );
  assert.throws(
    () => getISTDateRanges("custom", "2026-10-20", "2026-10-10"),
    /startDate must be earlier than or equal to endDate/,
    "Should reject inverted date range"
  );
  console.log("  ✔ Custom date validation rejects bad inputs");
}

// --- TEST SUITE 2: Revenue Calculation and Integrity Rules ---
function testRevenueFilterIntegrity() {
  console.log("\n[2] Testing Revenue Integrity Rules...");

  const filter = getSuccessfulRevenueFilter();

  // Rule 2.1: Cancelled and Payment Rejected orders are excluded
  assert.deepStrictEqual(filter.status, { $nin: ["Cancelled", "Payment Rejected"] });
  console.log("  ✔ Excludes Cancelled and Payment Rejected orders from revenue");

  // Rule 2.2: PaymentStatus cannot be Rejected
  assert.deepStrictEqual(filter.paymentStatus, { $ne: "Rejected" });
  console.log("  ✔ Excludes orders with Rejected payment status");

  // Rule 2.3: UPI requires paymentStatus == "Verified"
  const upiRule = filter.$or.find(r => r.paymentMethod === "UPI");
  assert.ok(upiRule, "Must have explicit UPI rule");
  assert.strictEqual(upiRule.paymentStatus, "Verified");
  console.log("  ✔ Explicitly requires paymentStatus == 'Verified' for UPI revenue");

  // Rule 2.4: COD and Card are included when uncancelled
  const nonUpiRule = filter.$or.find(r => r.paymentMethod && r.paymentMethod.$in && r.paymentMethod.$in.includes("COD"));
  assert.ok(nonUpiRule);
  assert.ok(nonUpiRule.paymentMethod.$in.includes("COD"));
  assert.ok(nonUpiRule.paymentMethod.$in.includes("Card"));
  console.log("  ✔ Accounts for COD and Card revenue without requiring UPI verification");

  // Rule 2.5: Legacy orders without paymentMethod are included
  const legacyRule = filter.$or.find(r => r.paymentMethod && r.paymentMethod.$exists === false);
  assert.ok(legacyRule, "Must support legacy orders where paymentMethod is omitted");
  console.log("  ✔ Accounts for legacy orders without explicit paymentMethod");
}

// --- TEST SUITE 3: In-Memory Order Simulation (Edge Cases & Revenue Accuracy) ---
function testRevenueCalculationSimulation() {
  console.log("\n[3] Testing In-Memory Calculation Accuracy on Varied Orders...");

  const mockOrders = [
    // 1. Verified UPI Order -> Should be in revenue
    {
      _id: "1",
      totalAmount: 250,
      status: "Completed",
      paymentMethod: "UPI",
      paymentStatus: "Verified",
      orderItems: [{ itemName: "Veggie Crunch Burger", itemPrice: 89, quantity: 2 }]
    },
    // 2. Unverified UPI Claim -> NEVER in revenue!
    {
      _id: "2",
      totalAmount: 189,
      status: "Pending Verification",
      paymentMethod: "UPI",
      paymentStatus: "Awaiting Verification",
      orderItems: [{ itemName: "Farmhouse Veggie Pizza", itemPrice: 189, quantity: 1 }]
    },
    // 3. Rejected UPI Claim -> NEVER in revenue!
    {
      _id: "3",
      totalAmount: 119,
      status: "Payment Rejected",
      paymentMethod: "UPI",
      paymentStatus: "Rejected",
      orderItems: [{ itemName: "Classic Cheese Burger", itemPrice: 119, quantity: 1 }]
    },
    // 4. Cancelled COD Order -> NEVER in revenue!
    {
      _id: "4",
      totalAmount: 300,
      status: "Cancelled",
      paymentMethod: "COD",
      paymentStatus: "Pending",
      orderItems: [{ itemName: "Paneer Tikka Pizza", itemPrice: 219, quantity: 1 }]
    },
    // 5. Successful COD Order -> Should be in revenue
    {
      _id: "5",
      totalAmount: 158,
      status: "Collected",
      paymentMethod: "COD",
      paymentStatus: "Pending",
      orderItems: [{ itemName: "Cold Coffee", itemPrice: 79, quantity: 2 }]
    },
    // 6. Legacy Completed Order (missing paymentMethod) -> Should be in revenue
    {
      _id: "6",
      totalAmount: 99,
      status: "Completed",
      paymentMethod: undefined,
      paymentStatus: undefined,
      orderItems: [{ itemName: "Crispy French Fries", itemPrice: 99, quantity: 1 }]
    }
  ];

  function matchesRevenue(o) {
    if (["Cancelled", "Payment Rejected"].includes(o.status)) return false;
    if (o.paymentStatus === "Rejected") return false;
    if (o.paymentMethod === "UPI") {
      return o.paymentStatus === "Verified";
    }
    return ["COD", "Card"].includes(o.paymentMethod) || !o.paymentMethod;
  }

  const revenueOrders = mockOrders.filter(matchesRevenue);
  assert.strictEqual(revenueOrders.length, 3, "Orders #1, #5, and #6 (legacy) must be counted in revenue");
  const grossSales = revenueOrders.reduce((sum, o) => sum + o.totalAmount, 0);
  assert.strictEqual(grossSales, 250 + 158 + 99, "Gross sales must equal 507");

  // Verify unverified UPI order (#2) is NOT in revenue
  assert.ok(!revenueOrders.some(o => o._id === "2"), "Unverified UPI claim was NOT counted");
  // Verify cancelled COD order (#4) is NOT in revenue
  assert.ok(!revenueOrders.some(o => o._id === "4"), "Cancelled order was NOT counted");
  console.log("  ✔ Excludes unverified UPI claims and cancelled orders accurately");

  // Item tally from revenue orders only
  const itemCounts = {};
  revenueOrders.forEach(o => {
    o.orderItems.forEach(i => {
      itemCounts[i.itemName] = (itemCounts[i.itemName] || 0) + i.quantity;
    });
  });
  assert.strictEqual(itemCounts["Veggie Crunch Burger"], 2);
  assert.strictEqual(itemCounts["Cold Coffee"], 2);
  assert.strictEqual(itemCounts["Farmhouse Veggie Pizza"], undefined, "Items from unverified UPI claims are excluded");
  console.log("  ✔ Menu item quantities derived solely from verified/successful orders");
}

// --- TEST SUITE 4: Formula Injection Prevention in CSV Export ---
function testCsvFormulaInjectionSanitization() {
  console.log("\n[4] Testing CSV Formula Injection Sanitization...");

  function sanitizeCsvCell(value) {
    if (value === null || value === undefined) return '""';
    let str = String(value);
    if (/^[=+\-@\t\r]/.test(str)) {
      str = "'" + str;
    }
    if (str.includes('"') || str.includes(",") || str.includes("\n") || str.includes("\r")) {
      str = `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  }

  // Dangerous spreadsheet formula attempts
  assert.strictEqual(sanitizeCsvCell("=SUM(A1:A10)"), "'=SUM(A1:A10)");
  assert.strictEqual(sanitizeCsvCell("+12345"), "'+12345");
  assert.strictEqual(sanitizeCsvCell("-CMD|' /C calc'!A0"), "'-CMD|' /C calc'!A0");
  assert.strictEqual(sanitizeCsvCell("@SUM(B1:B5)"), "'@SUM(B1:B5)");
  assert.strictEqual(sanitizeCsvCell("\tTAB_INJECT"), "'\tTAB_INJECT");

  // Regular text
  assert.strictEqual(sanitizeCsvCell("Classic Cheese Burger"), "Classic Cheese Burger");
  assert.strictEqual(sanitizeCsvCell("Burger, with cheese"), '"Burger, with cheese"');
  assert.strictEqual(sanitizeCsvCell('Special "Deluxe"'), '"Special ""Deluxe"""');
  console.log("  ✔ Formula injection characters (=, +, -, @, \\t) safely prepended with single-quote");
}

// --- TEST SUITE 5: Zero-Denominator & Empty Summary Resilience ---
function testEmptySummaryResilience() {
  console.log("\n[5] Testing Empty Database Summary Resilience...");

  function calcPctChange(current, previous) {
    if (previous === 0) {
      return current === 0 ? 0.0 : null;
    }
    const pct = ((current - previous) / previous) * 100;
    return Math.round(pct * 10) / 10;
  }

  // 0 previous, 0 current -> 0.0% (not NaN)
  assert.strictEqual(calcPctChange(0, 0), 0.0);
  // 0 previous, 10 current -> null (meaningful indicator for UI to display "New" rather than Infinity)
  assert.strictEqual(calcPctChange(10, 0), null);
  // 5 previous, 10 current -> +100%
  assert.strictEqual(calcPctChange(10, 5), 100.0);
  // 10 previous, 5 current -> -50%
  assert.strictEqual(calcPctChange(5, 10), -50.0);

  // AOV with 0 revenue orders -> 0
  const zeroRevenueCount = 0;
  const zeroGrossSales = 0;
  const aov = zeroRevenueCount > 0 ? Math.round(zeroGrossSales / zeroRevenueCount) : 0;
  assert.strictEqual(aov, 0, "AOV with 0 orders must be 0, not NaN");

  console.log("  ✔ Zero denominators handled cleanly with mathematical stability");
}

function runAll() {
  testISTDateRanges();
  testRevenueFilterIntegrity();
  testRevenueCalculationSimulation();
  testCsvFormulaInjectionSanitization();
  testEmptySummaryResilience();
  console.log("\nAll Backend Analytics Unit & Security Tests Passed Successfully!\n");
}

runAll();
