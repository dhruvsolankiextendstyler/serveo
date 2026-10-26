import assert from "assert";
import { updateStatusController } from "./controllers/updateStatusController.js";

console.log("--- Testing Order Security & Status Transition Rules ---");

// Test 1: updateStatusController rejects missing ID
async function testMissingId() {
    try {
        await updateStatusController({ body: { newStatus: "Preparing" } });
        assert.fail("Should throw on missing id");
    } catch (e) {
        assert.strictEqual(e.message, "Order ID is required");
        console.log("✔ Rejects updateStatus without order ID");
    }
}

// Test 2: updateStatusController rejects missing newStatus
async function testMissingStatus() {
    try {
        await updateStatusController({ body: { id: "507f1f77bcf86cd799439011" } });
        assert.fail("Should throw on missing newStatus");
    } catch (e) {
        assert.strictEqual(e.message, "New status is required");
        console.log("✔ Rejects updateStatus without newStatus");
    }
}

// Test 3: updateStatusController rejects arbitrary/invalid status
async function testInvalidStatus() {
    try {
        await updateStatusController({
            body: { id: "507f1f77bcf86cd799439011", newStatus: "HACKED_STATUS" }
        });
        assert.fail("Should throw on invalid status");
    } catch (e) {
        assert.ok(e.message.includes("Invalid status 'HACKED_STATUS'"));
        console.log("✔ Rejects arbitrary or non-enum status values");
    }
}

async function runTests() {
    await testMissingId();
    await testMissingStatus();
    await testInvalidStatus();
    console.log("All Backend Security & Status Transition Tests Passed Successfully!");
    process.exit(0);
}

runTests();
