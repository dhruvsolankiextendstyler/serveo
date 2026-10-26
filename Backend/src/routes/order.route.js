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

export const orderRoute = express.Router()

orderRoute.get("/", async (req,res) => {
    try {
        const msg = await getOrderController()
        res.json({"message": msg})
        console.log("All Orders sent")
    } catch (error) {
        res.status(500).json({"error": error.message})
    }
})

orderRoute.get("/user", authCheck, async (req,res) => {
    try {
        const msg = await getUserOrderController(req)
        res.json({"message": msg})
        console.log("User Orders sent")
    } catch (error) {
        res.status(500).json({"error": error.message})
    }
})

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
        res.status(400).json({"error": error.message})
    }
})

orderRoute.patch("/claim-payment", authCheck, async (req,res) => {
    try {
        const result = await claimPaymentController(req)
        res.json(result)
        console.log("Payment Claimed:", req.body.orderId)
    } catch (error) {
        console.error("Claim Payment Error:", error.message)
        res.status(400).json({"error": error.message})
    }
})

orderRoute.patch("/verify-payment", adminCheck, async (req,res) => {
    try {
        const result = await verifyPaymentController(req)
        res.json(result)
        console.log("Payment Verification Processed:", req.body.orderId)
    } catch (error) {
        console.error("Verify Payment Error:", error.message)
        res.status(400).json({"error": error.message})
    }
})

orderRoute.patch("/updatestatus", async (req,res) => {
    try {
        const msg = await updateStatusController(req)
        res.json({"message": msg})
        console.log("Status Updated")
    } catch (error) {
        res.status(400).json({"error": error.message})
    }
})

orderRoute.patch("/updatecollected", async (req,res) => {
    const msg = await updateCollectedController(req)
    res.json({"message": msg})
    console.log("Order Collected")
})

orderRoute.get("/userReport", authCheck, async (req,res) => {
    const msg = await getUserReportController(req)
    res.json({"message": msg})
    console.log("User Report Sent")
})

orderRoute.get("/:tr", adminCheck, async (req,res) => {
    const msg = await getReportController(req)
    res.json({"message": msg})
    console.log("Report Sent")
})