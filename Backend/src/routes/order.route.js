import express from 'express'
import { getOrderController } from '../controllers/getOrder.controller.js'
import { addOrderController } from '../controllers/addOrder.controller.js'
import { updateStatusController } from '../controllers/updateStatusController.js'
import { authCheck } from '../middlewares/authCheck.js'
import { getUserOrderController } from '../controllers/getUserOrder.controller.js'
import { updateCollectedController } from '../controllers/updateCollected.controller.js'
import { adminCheck } from '../middlewares/adminCheck.js'
import { getReportController } from '../controllers/getReport.controller.js'
import { getUserReportController } from '../controllers/getUserReport.controller.js'
import { claimPaymentController } from '../controllers/claimPayment.controller.js'
import { verifyPaymentController } from '../controllers/verifyPayment.controller.js'
import { analyticsRoute } from './analytics.route.js'
import { trackOrderController } from '../controllers/trackOrder.controller.js'

import { getUserNotificationsController, markNotificationReadController, markAllNotificationsReadController } from '../controllers/notification.controller.js'
import { submitFeedbackController, getOrderFeedbackController, getAdminFeedbackController } from '../controllers/feedback.controller.js'
import { Order } from '../models/order.models.js'

export const orderRoute = express.Router()

// 🔹 Analytics Endpoints (Admin Only, protected)
orderRoute.use("/analytics", analyticsRoute)

// 🔹 1. GET ALL ORDERS (Admin Only, scoped to authorized restaurant)
orderRoute.get("/", adminCheck, async (req,res) => {
    try {
        const msg = await getOrderController(req)
        res.json({"message": msg})
        console.log("Restaurant Orders sent for:", req.restaurant?.name)
    } catch (error) {
        res.status(500).json({"error": error.message})
    }
})

// 🔹 2. GET USER ORDERS (Customer, protected to own user)
orderRoute.get("/user", authCheck, async (req,res) => {
    try {
        const msg = await getUserOrderController(req)
        res.json({"message": msg})
        console.log("User Orders sent")
    } catch (error) {
        res.status(500).json({"error": error.message})
    }
})

// 🔹 2b. TRACK SINGLE ORDER (Customer, verified ownership)
orderRoute.get("/track/:id", authCheck, async (req, res) => {
    try {
        const orderData = await trackOrderController(req);
        res.json({ order: orderData });
    } catch (error) {
        res.status(error.status || 500).json({ error: error.message });
    }
})

// 🔹 2c. GET ORDER DETAILS (Customer, verified ownership)
orderRoute.get("/detail/:id", authCheck, async (req, res) => {
    try {
        const orderData = await trackOrderController(req);
        res.json({ order: orderData });
    } catch (error) {
        res.status(error.status || 500).json({ error: error.message });
    }
})

// 🔹 2d. NOTIFICATIONS (Customer, in-app persistent notifications)
orderRoute.get("/notifications/user", authCheck, async (req, res) => {
    try {
        const data = await getUserNotificationsController(req);
        res.json(data);
    } catch (error) {
        res.status(error.status || 500).json({ error: error.message });
    }
})

orderRoute.patch("/notifications/read-all", authCheck, async (req, res) => {
    try {
        const result = await markAllNotificationsReadController(req);
        res.json(result);
    } catch (error) {
        res.status(error.status || 500).json({ error: error.message });
    }
})

orderRoute.patch("/notifications/:id/read", authCheck, async (req, res) => {
    try {
        const result = await markNotificationReadController(req);
        res.json(result);
    } catch (error) {
        res.status(error.status || 500).json({ error: error.message });
    }
})

// 🔹 2e. FEEDBACK (Customer rating & reviews, Admin overview)
orderRoute.post("/feedback", authCheck, async (req, res) => {
    try {
        const result = await submitFeedbackController(req);
        res.status(201).json(result);
    } catch (error) {
        res.status(error.status || 400).json({ error: error.message });
    }
})

orderRoute.get("/feedback/admin/all", adminCheck, async (req, res) => {
    try {
        const result = await getAdminFeedbackController(req);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
})

orderRoute.get("/feedback/order/:orderId", authCheck, async (req, res) => {
    try {
        const feedback = await getOrderFeedbackController(req);
        res.json({ feedback });
    } catch (error) {
        res.status(error.status || 400).json({ error: error.message });
    }
})

// 🔹 3. CREATE ORDER (Customer, protected)
orderRoute.post("/add", authCheck, async (req,res) => {
    try {
        const result = await addOrderController(req)
        res.status(201).json({
            "message": result.message || result,
            "order": result.order
        })
        console.log("Order added")
    } catch (error) {
        console.error("Add Order Error:", error.message)
        res.status(error.status || 400).json({"error": error.message})
    }
})

// 🔹 4. CLAIM UPI PAYMENT (Customer, protected to order owner)
orderRoute.patch("/claim-payment", authCheck, async (req,res) => {
    try {
        const result = await claimPaymentController(req)
        res.json(result)
        console.log("Payment Claimed:", req.body.orderId)
    } catch (error) {
        console.error("Claim Payment Error:", error.message)
        res.status(error.status || 400).json({"error": error.message})
    }
})

// 🔹 5. VERIFY UPI PAYMENT (Admin Only, protected)
orderRoute.patch("/verify-payment", adminCheck, async (req,res) => {
    try {
        const result = await verifyPaymentController(req)
        res.json(result)
        console.log("Payment Verification Processed:", req.body.orderId)
    } catch (error) {
        console.error("Verify Payment Error:", error.message)
        res.status(error.status || 400).json({"error": error.message})
    }
})

// 🔹 5b. UPDATE ESTIMATED PREPARATION TIME (Admin Only, protected)
orderRoute.patch("/estimated-time", adminCheck, async (req, res) => {
    try {
        const { orderId, estimatedPrepTime } = req.body;
        if (!orderId || !estimatedPrepTime) {
            return res.status(400).json({ error: "orderId and estimatedPrepTime (in minutes) are required" });
        }
        const order = await Order.findById(orderId);
        if (!order) {
            return res.status(404).json({ error: "Order not found" });
        }
        // Tenant check
        if (req.restaurantId && order.restaurantId && order.restaurantId.toString() !== req.restaurantId.toString()) {
            return res.status(403).json({ error: "Unauthorized to update order from another restaurant" });
        }
        const mins = Math.max(1, Math.min(Number(estimatedPrepTime) || 15, 120));
        order.estimatedPrepTime = mins;
        order.estimatedReadyAt = new Date(Date.now() + mins * 60 * 1000);
        await order.save();
        res.json({ message: "Estimated preparation time updated", order });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
})

// 🔹 6. UPDATE ORDER STATUS (Admin Only, protected)
orderRoute.patch("/updatestatus", adminCheck, async (req,res) => {
    try {
        const msg = await updateStatusController(req)
        res.json({"message": msg})
        console.log("Status Updated")
    } catch (error) {
        res.status(error.status || 400).json({"error": error.message})
    }
})

// 🔹 7. MARK AS COLLECTED (Receipt presentation at counter)
orderRoute.patch("/updatecollected", async (req,res) => {
    try {
        const msg = await updateCollectedController(req)
        res.json({"message": msg})
        console.log("Order Collected")
    } catch (error) {
        res.status(400).json({"error": error.message})
    }
})

// 🔹 8. USER REPORT (Customer, protected)
orderRoute.get("/userReport", authCheck, async (req,res) => {
    try {
        const msg = await getUserReportController(req)
        res.json({"message": msg})
        console.log("User Report Sent")
    } catch (error) {
        res.status(500).json({"error": error.message})
    }
})

// 🔹 9. ADMIN REPORT (Admin Only, protected)
orderRoute.get("/:tr", adminCheck, async (req,res) => {
    try {
        const msg = await getReportController(req)
        res.json({"message": msg})
        console.log("Report Sent")
    } catch (error) {
        res.status(500).json({"error": error.message})
    }
})
