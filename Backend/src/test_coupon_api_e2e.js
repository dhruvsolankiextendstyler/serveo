import assert from "assert";
import mongoose from "mongoose";
import { DBConnect } from "./utils/db_connect.js";
import { Restaurant } from "./models/restaurant.models.js";
import { Coupon } from "./models/coupon.models.js";
import {
  createCouponController,
  getAdminCouponsController,
  validateAndCalculateCouponDiscount,
} from "./controllers/coupon.controller.js";
import { requireRoles, requirePlanFeature } from "./middlewares/adminCheck.js";

console.log("\n=== Running Coupon Creation API End-to-End Verification Test ===");

async function runE2ETests() {
  await DBConnect();

  const testRestId = new mongoose.Types.ObjectId("672000000000000000000999");
  const testStaffEmail = "manager_test@serveo.app";

  // Clean any previous test coupons
  await Coupon.deleteMany({ restaurantId: testRestId });
  await Restaurant.deleteOne({ _id: testRestId });

  // 1. Create a test restaurant with Growth plan (features.marketingAndLoyalty: true)
  const testRestaurant = new Restaurant({
    _id: testRestId,
    name: "E2E Test Cafe",
    slug: "e2e-test-cafe",
    subscription: {
      planId: "growth",
      status: "active",
      startDate: new Date(),
    },
    staff: [
      {
        email: testStaffEmail,
        name: "Test Manager",
        role: "manager",
        isActive: true,
      },
    ],
  });
  await testRestaurant.save();

  // Helper mock response
  function createMockRes() {
    return {
      statusCode: 200,
      jsonData: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.jsonData = data;
        return this;
      },
    };
  }

  // --- Test 1: Create Percentage Coupon ---
  console.log("\n[1] Testing Percentage Coupon Creation...");
  {
    const req = {
      restaurantId: testRestId,
      restaurant: testRestaurant,
      staffRole: "manager",
      user: { email: testStaffEmail },
      body: {
        code: "SUMMER30",
        description: "30% off summer discount",
        discountType: "percentage",
        discountValue: 30,
        maxDiscountAmount: 150,
        minOrderValue: 200,
        validUntil: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
        totalUsageLimit: 50,
        perCustomerLimit: 2,
      },
    };
    const res = createMockRes();

    await createCouponController(req, res);
    assert.strictEqual(res.statusCode, 201, `Expected 201 Created, got ${res.statusCode}: ${JSON.stringify(res.jsonData)}`);
    assert.strictEqual(res.jsonData.coupon.code, "SUMMER30");
    assert.strictEqual(res.jsonData.coupon.discountType, "percentage");
    assert.strictEqual(res.jsonData.coupon.discountValue, 30);
    assert.strictEqual(res.jsonData.coupon.maxDiscountAmount, 150);
    assert.strictEqual(res.jsonData.coupon.minOrderValue, 200);
    assert.strictEqual(res.jsonData.coupon.perCustomerLimit, 2);
    assert.strictEqual(res.jsonData.coupon.totalUsageLimit, 50);
    console.log("  ✔ Percentage coupon created with HTTP 201 and correct attributes");
  }

  // --- Test 2: Create Fixed Amount Coupon with Frontend Field Names ---
  console.log("\n[2] Testing Fixed Amount Coupon with Frontend Aliased Fields...");
  {
    const req = {
      restaurantId: testRestId,
      restaurant: testRestaurant,
      staffRole: "manager",
      user: { email: testStaffEmail },
      body: {
        code: "FLAT100",
        description: "Flat ₹100 discount",
        discountType: "fixed",
        discountValue: 100,
        maxDiscount: 100, // Aliased field from Flutter
        minOrderValue: 300,
        validUntil: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(), // Aliased field from Flutter
        totalUsageLimit: 20,
        perCustomerLimit: 1,
      },
    };
    const res = createMockRes();

    await createCouponController(req, res);
    assert.strictEqual(res.statusCode, 201, `Expected 201 Created, got ${res.statusCode}: ${JSON.stringify(res.jsonData)}`);
    assert.strictEqual(res.jsonData.coupon.code, "FLAT100");
    assert.strictEqual(res.jsonData.coupon.discountType, "fixed");
    assert.strictEqual(res.jsonData.coupon.discountValue, 100);
    assert.strictEqual(res.jsonData.coupon.maxDiscountAmount, 100);
    assert.ok(res.jsonData.coupon.endDate, "endDate should be resolved from validUntil");
    console.log("  ✔ Fixed amount coupon created with aliased maxDiscount and validUntil fields");
  }

  // --- Test 3: Duplicate Coupon Code Prevention ---
  console.log("\n[3] Testing Duplicate Coupon Code Prevention...");
  {
    const req = {
      restaurantId: testRestId,
      restaurant: testRestaurant,
      staffRole: "manager",
      user: { email: testStaffEmail },
      body: {
        code: "summer30", // Lowercase duplicate of SUMMER30
        discountType: "percentage",
        discountValue: 20,
      },
    };
    const res = createMockRes();

    await createCouponController(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.ok(res.jsonData.error.includes("already exists"));
    console.log("  ✔ Duplicate coupon code strictly rejected with HTTP 400");
  }

  // --- Test 4: Invalid Discount Values Validation ---
  console.log("\n[4] Testing Invalid Discount Values Validation...");
  {
    // A: Negative value
    const reqNeg = {
      restaurantId: testRestId,
      body: { code: "NEGATIVE", discountType: "fixed", discountValue: -50 },
    };
    const resNeg = createMockRes();
    await createCouponController(reqNeg, resNeg);
    assert.strictEqual(resNeg.statusCode, 400);

    // B: Percentage > 100
    const reqOver = {
      restaurantId: testRestId,
      body: { code: "OVER100", discountType: "percentage", discountValue: 150 },
    };
    const resOver = createMockRes();
    await createCouponController(reqOver, resOver);
    assert.strictEqual(resOver.statusCode, 400);
    assert.ok(resOver.jsonData.error.includes("exceed 100%"));

    // C: Negative minOrderValue
    const reqMinOrderNeg = {
      restaurantId: testRestId,
      body: { code: "NEGORDER", discountType: "fixed", discountValue: 50, minOrderValue: -10 },
    };
    const resMinOrderNeg = createMockRes();
    await createCouponController(reqMinOrderNeg, resMinOrderNeg);
    assert.strictEqual(resMinOrderNeg.statusCode, 400);
    assert.ok(resMinOrderNeg.jsonData.error.includes("cannot be negative"));

    // D: Expiry date before start date
    const reqDate = {
      restaurantId: testRestId,
      body: {
        code: "BADDATE",
        discountType: "fixed",
        discountValue: 50,
        startDate: new Date(Date.now() + 500000),
        endDate: new Date(Date.now() - 500000),
      },
    };
    const resDate = createMockRes();
    await createCouponController(reqDate, resDate);
    assert.strictEqual(resDate.statusCode, 400);
    assert.ok(resDate.jsonData.error.includes("earlier than start date"));

    console.log("  ✔ Negative values, >100% percentage, and invalid dates strictly rejected with HTTP 400");
  }

  // --- Test 5: Role & Plan Feature Authorization Middleware ---
  console.log("\n[5] Testing RBAC and Plan Feature Gate Middleware...");
  {
    // A: requireRoles blocks "viewer"
    let rolesPassed = false;
    const reqViewer = { staffRole: "viewer", restaurantId: testRestId };
    const resViewer = createMockRes();
    requireRoles(["owner", "manager"])(reqViewer, resViewer, () => {
      rolesPassed = true;
    });
    assert.strictEqual(rolesPassed, false);
    assert.strictEqual(resViewer.statusCode, 403);
    assert.strictEqual(resViewer.jsonData.error, "FORBIDDEN_ROLE");

    // B: requirePlanFeature blocks "starter" plan
    let planPassed = false;
    const reqStarter = {
      restaurant: { subscription: { planId: "starter" } },
      restaurantId: testRestId,
    };
    const resStarter = createMockRes();
    requirePlanFeature("marketingAndLoyalty")(reqStarter, resStarter, () => {
      planPassed = true;
    });
    assert.strictEqual(planPassed, false);
    assert.strictEqual(resStarter.statusCode, 403);
    assert.strictEqual(resStarter.jsonData.error, "FEATURE_NOT_IN_PLAN");

    // C: Growth plan allows through
    let growthPassed = false;
    const reqGrowth = {
      restaurant: { subscription: { planId: "growth" } },
      restaurantId: testRestId,
    };
    const resGrowth = createMockRes();
    requirePlanFeature("marketingAndLoyalty")(reqGrowth, resGrowth, () => {
      growthPassed = true;
    });
    assert.strictEqual(growthPassed, true);

    console.log("  ✔ Role checks and subscription feature gates verified");
  }

  // --- Test 6: Verify MongoDB Persistence & Admin Coupon List ---
  console.log("\n[6] Testing MongoDB Persistence & Admin Coupon List Summary...");
  {
    const persisted = await Coupon.find({ restaurantId: testRestId });
    assert.strictEqual(persisted.length, 2, "Expected 2 coupons in MongoDB");
    const codes = persisted.map((c) => c.code).sort();
    assert.deepStrictEqual(codes, ["FLAT100", "SUMMER30"]);

    const reqList = { restaurantId: testRestId };
    const resList = createMockRes();
    await getAdminCouponsController(reqList, resList);
    assert.strictEqual(resList.statusCode, 200);
    assert.strictEqual(resList.jsonData.coupons.length, 2);
    assert.ok(resList.jsonData.coupons.some((c) => c.code === "SUMMER30"));
    assert.ok(resList.jsonData.coupons.some((c) => c.code === "FLAT100"));
    console.log("  ✔ Coupons persisted in MongoDB Atlas and verified in Admin List");
  }

  // --- Test 7: Verify Customer Validation and Checkout Discount Calculation ---
  console.log("\n[7] Testing Customer Checkout Calculation Against Created Coupons...");
  {
    // A: Apply SUMMER30 to subtotal ₹300 (30% of 300 = 90, cap 150 -> 90)
    const preview1 = await validateAndCalculateCouponDiscount({
      couponCode: "SUMMER30",
      restaurantId: testRestId,
      subtotal: 300,
    });
    assert.strictEqual(preview1.isValid, true);
    assert.strictEqual(preview1.discountAmount, 90);

    // B: Apply SUMMER30 to subtotal ₹100 (below minOrderValue of 200)
    const previewMin = await validateAndCalculateCouponDiscount({
      couponCode: "SUMMER30",
      restaurantId: testRestId,
      subtotal: 100,
    });
    assert.strictEqual(previewMin.isValid, false);
    assert.ok(previewMin.message.includes("Minimum order value"));

    // C: Apply FLAT100 to subtotal ₹500
    const previewFlat = await validateAndCalculateCouponDiscount({
      couponCode: "FLAT100",
      restaurantId: testRestId,
      subtotal: 500,
    });
    assert.strictEqual(previewFlat.isValid, true);
    assert.strictEqual(previewFlat.discountAmount, 100);

    console.log("  ✔ Customer checkout calculation accurately computed discounts and enforced restrictions");
  }

  // Cleanup test records
  await Coupon.deleteMany({ restaurantId: testRestId });
  await Restaurant.deleteOne({ _id: testRestId });
  console.log("\n Cleaned up test artifacts cleanly.");
  console.log("\n All Coupon Creation API End-to-End Tests Passed Successfully! \n");

  await mongoose.disconnect();
}

runE2ETests().catch((err) => {
  console.error("Test failed with error:", err);
  process.exit(1);
});

