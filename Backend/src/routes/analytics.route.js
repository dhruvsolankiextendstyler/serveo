import express from "express";
import { adminCheck } from "../middlewares/adminCheck.js";
import {
  getAnalyticsOverviewController,
  getSalesChartController,
  getOrderPerformanceController,
  getPopularItemsController,
  getPeakHoursController,
  getPaymentAnalyticsController,
  getAnalyticsDashboardController,
  getAnalyticsExportController
} from "../controllers/analytics.controller.js";

export const analyticsRoute = express.Router();

// Enforce adminCheck on all analytics endpoints
analyticsRoute.use(adminCheck);

// 0. Consolidated Dashboard (All sections in one optimized single-trip query)
analyticsRoute.get("/dashboard", getAnalyticsDashboardController);

// 1. Executive Summary & KPI Cards
analyticsRoute.get("/overview", getAnalyticsOverviewController);

// 2. Sales Timeline Chart (Hourly / Daily)
analyticsRoute.get("/sales", getSalesChartController);

// 3. Order Performance & Completion Rates
analyticsRoute.get("/orders", getOrderPerformanceController);

// 4. Menu Item Insights (Popular & Underperforming)
analyticsRoute.get("/items", getPopularItemsController);

// 5. Peak Ordering Times (Hours & Days)
analyticsRoute.get("/peak-hours", getPeakHoursController);

// 6. Payment Analytics & UPI Verification Claims
analyticsRoute.get("/payments", getPaymentAnalyticsController);

// 7. CSV Report Export
analyticsRoute.get("/export", getAnalyticsExportController);
