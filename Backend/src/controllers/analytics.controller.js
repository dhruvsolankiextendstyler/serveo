import { Order } from "../models/order.models.js";
import { Item } from "../models/item.models.js";

// Asia/Kolkata timezone offset is UTC+05:30 (+330 minutes)
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
const IST_TZ_STRING = "+05:30";

function getRestaurantFilter(restaurantId) {
  if (!restaurantId) return {};
  return {
    $or: [
      { restaurantId: restaurantId },
      { restaurantId: { $exists: false } },
      { restaurantId: null }
    ]
  };
}

/**
 * Calculates start and end timestamps in UTC aligned to Asia/Kolkata (IST) midnight boundaries.
 * Also computes the equivalent previous historical period for comparative analytics.
 */
export function getISTDateRanges(timeframe = "today", customStart = null, customEnd = null) {
  const nowUtc = new Date();
  const nowIst = new Date(nowUtc.getTime() + IST_OFFSET_MS);

  const istYear = nowIst.getUTCFullYear();
  const istMonth = nowIst.getUTCMonth(); // 0-indexed
  const istDate = nowIst.getUTCDate();

  let startUtc;
  let endUtc;
  let prevStartUtc;
  let prevEndUtc;
  let label = "Today";
  let isSingleDay = false;

  switch (timeframe.toLowerCase()) {
    case "yesterday": {
      isSingleDay = true;
      label = "Yesterday";
      startUtc = new Date(Date.UTC(istYear, istMonth, istDate - 1, 0, 0, 0, 0) - IST_OFFSET_MS);
      endUtc = new Date(Date.UTC(istYear, istMonth, istDate - 1, 23, 59, 59, 999) - IST_OFFSET_MS);
      prevStartUtc = new Date(Date.UTC(istYear, istMonth, istDate - 2, 0, 0, 0, 0) - IST_OFFSET_MS);
      prevEndUtc = new Date(Date.UTC(istYear, istMonth, istDate - 2, 23, 59, 59, 999) - IST_OFFSET_MS);
      break;
    }

    case "7d":
    case "last7days": {
      label = "Last 7 Days";
      startUtc = new Date(Date.UTC(istYear, istMonth, istDate - 6, 0, 0, 0, 0) - IST_OFFSET_MS);
      endUtc = new Date(Date.UTC(istYear, istMonth, istDate, 23, 59, 59, 999) - IST_OFFSET_MS);
      prevStartUtc = new Date(Date.UTC(istYear, istMonth, istDate - 13, 0, 0, 0, 0) - IST_OFFSET_MS);
      prevEndUtc = new Date(Date.UTC(istYear, istMonth, istDate - 7, 23, 59, 59, 999) - IST_OFFSET_MS);
      break;
    }

    case "30d":
    case "last30days": {
      label = "Last 30 Days";
      startUtc = new Date(Date.UTC(istYear, istMonth, istDate - 29, 0, 0, 0, 0) - IST_OFFSET_MS);
      endUtc = new Date(Date.UTC(istYear, istMonth, istDate, 23, 59, 59, 999) - IST_OFFSET_MS);
      prevStartUtc = new Date(Date.UTC(istYear, istMonth, istDate - 59, 0, 0, 0, 0) - IST_OFFSET_MS);
      prevEndUtc = new Date(Date.UTC(istYear, istMonth, istDate - 30, 23, 59, 59, 999) - IST_OFFSET_MS);
      break;
    }

    case "this_month":
    case "thismonth": {
      label = "This Month";
      startUtc = new Date(Date.UTC(istYear, istMonth, 1, 0, 0, 0, 0) - IST_OFFSET_MS);
      endUtc = new Date(Date.UTC(istYear, istMonth, istDate, 23, 59, 59, 999) - IST_OFFSET_MS);
      prevStartUtc = new Date(Date.UTC(istYear, istMonth - 1, 1, 0, 0, 0, 0) - IST_OFFSET_MS);
      prevEndUtc = new Date(Date.UTC(istYear, istMonth - 1, Math.min(istDate, new Date(istYear, istMonth, 0).getDate()), 23, 59, 59, 999) - IST_OFFSET_MS);
      break;
    }

    case "prev_month":
    case "previousmonth": {
      label = "Previous Month";
      startUtc = new Date(Date.UTC(istYear, istMonth - 1, 1, 0, 0, 0, 0) - IST_OFFSET_MS);
      const lastDayPrevMonth = new Date(Date.UTC(istYear, istMonth, 0)).getUTCDate();
      endUtc = new Date(Date.UTC(istYear, istMonth - 1, lastDayPrevMonth, 23, 59, 59, 999) - IST_OFFSET_MS);
      const lastDayTwoMonthsPrior = new Date(Date.UTC(istYear, istMonth - 1, 0)).getUTCDate();
      prevStartUtc = new Date(Date.UTC(istYear, istMonth - 2, 1, 0, 0, 0, 0) - IST_OFFSET_MS);
      prevEndUtc = new Date(Date.UTC(istYear, istMonth - 2, lastDayTwoMonthsPrior, 23, 59, 59, 999) - IST_OFFSET_MS);
      break;
    }

    case "custom": {
      if (!customStart || !customEnd) {
        throw new Error("Both startDate and endDate are required for custom timeframe (format: YYYY-MM-DD)");
      }
      const sParts = customStart.split("-").map(Number);
      const eParts = customEnd.split("-").map(Number);
      if (sParts.length !== 3 || eParts.length !== 3 || sParts.some(isNaN) || eParts.some(isNaN)) {
        throw new Error("Invalid custom date format. Use YYYY-MM-DD.");
      }
      startUtc = new Date(Date.UTC(sParts[0], sParts[1] - 1, sParts[2], 0, 0, 0, 0) - IST_OFFSET_MS);
      endUtc = new Date(Date.UTC(eParts[0], eParts[1] - 1, eParts[2], 23, 59, 59, 999) - IST_OFFSET_MS);
      if (startUtc > endUtc) {
        throw new Error("startDate must be earlier than or equal to endDate");
      }
      isSingleDay = customStart === customEnd;
      label = isSingleDay ? `Custom (${customStart})` : `Custom (${customStart} to ${customEnd})`;
      const spanMs = endUtc.getTime() - startUtc.getTime();
      prevStartUtc = new Date(startUtc.getTime() - spanMs - 1);
      prevEndUtc = new Date(startUtc.getTime() - 1);
      break;
    }

    case "today":
    default: {
      isSingleDay = true;
      label = "Today";
      startUtc = new Date(Date.UTC(istYear, istMonth, istDate, 0, 0, 0, 0) - IST_OFFSET_MS);
      endUtc = new Date(Date.UTC(istYear, istMonth, istDate, 23, 59, 59, 999) - IST_OFFSET_MS);
      prevStartUtc = new Date(Date.UTC(istYear, istMonth, istDate - 1, 0, 0, 0, 0) - IST_OFFSET_MS);
      prevEndUtc = new Date(Date.UTC(istYear, istMonth, istDate - 1, 23, 59, 59, 999) - IST_OFFSET_MS);
      break;
    }
  }

  return {
    current: { start: startUtc, end: endUtc, label, isSingleDay },
    previous: { start: prevStartUtc, end: prevEndUtc, label: "Previous Period" },
    timezone: "Asia/Kolkata"
  };
}

/**
 * MongoDB Match condition for successful, verified revenue.
 */
export function getSuccessfulRevenueFilter() {
  return {
    status: { $nin: ["Cancelled", "Payment Rejected"] },
    paymentStatus: { $ne: "Rejected" },
    $or: [
      { paymentMethod: "UPI", paymentStatus: "Verified" },
      { paymentMethod: { $in: ["COD", "Card"] } },
      { paymentMethod: { $in: [null, ""] } },
      { paymentMethod: { $exists: false } }
    ]
  };
}

function calcPctChange(current, previous) {
  if (previous === 0) {
    return current === 0 ? 0.0 : null;
  }
  const pct = ((current - previous) / previous) * 100;
  return Math.round(pct * 10) / 10;
}

/**
 * Computes high-level overview metrics & comparisons scoped to restaurant.
 */
export async function computeOverviewData(timeframe = "today", startDate = null, endDate = null, restaurantId = null) {
  const { current, previous, timezone } = getISTDateRanges(timeframe, startDate, endDate);
  const restFilter = getRestaurantFilter(restaurantId);

  async function fetchRangeSummary(rangeStart, rangeEnd) {
    const results = await Order.aggregate([
      {
        $match: {
          createdAt: { $gte: rangeStart, $lte: rangeEnd },
          ...restFilter
        }
      },
      {
        $facet: {
          totalOrders: [{ $count: "count" }],
          completedOrders: [
            { $match: { status: { $in: ["Completed", "Collected"] } } },
            { $count: "count" }
          ],
          pendingOrders: [
            {
              $match: {
                status: {
                  $in: ["Pending", "Processing", "Accepted", "Preparing", "Ready", "Pending Verification"]
                }
              }
            },
            { $count: "count" }
          ],
          cancelledOrders: [
            { $match: { status: { $in: ["Cancelled", "Payment Rejected"] } } },
            { $count: "count" }
          ],
          revenueStats: [
            { $match: getSuccessfulRevenueFilter() },
            {
              $group: {
                _id: null,
                grossSales: { $sum: "$totalAmount" },
                revenueOrderCount: { $sum: 1 }
              }
            }
          ],
          pendingUpiVerifications: [
            {
              $match: {
                paymentMethod: "UPI",
                paymentStatus: "Awaiting Verification"
              }
            },
            { $count: "count" }
          ]
        }
      }
    ]);

    const facet = results[0] || {};
    const totalOrders = facet.totalOrders?.[0]?.count || 0;
    const completedOrders = facet.completedOrders?.[0]?.count || 0;
    const pendingOrders = facet.pendingOrders?.[0]?.count || 0;
    const cancelledOrders = facet.cancelledOrders?.[0]?.count || 0;
    const grossSales = facet.revenueStats?.[0]?.grossSales || 0;
    const revenueOrderCount = facet.revenueStats?.[0]?.revenueOrderCount || 0;
    const averageOrderValue = revenueOrderCount > 0 ? Math.round(grossSales / revenueOrderCount) : 0;
    const pendingUpiVerifications = facet.pendingUpiVerifications?.[0]?.count || 0;

    return {
      grossSales,
      netSales: grossSales,
      totalOrders,
      completedOrders,
      pendingOrders,
      cancelledOrders,
      averageOrderValue,
      pendingUpiVerifications
    };
  }

  const currentMetrics = await fetchRangeSummary(current.start, current.end);
  const previousMetrics = await fetchRangeSummary(previous.start, previous.end);

  return {
    selectedRange: {
      timeframe,
      label: current.label,
      start: current.start.toISOString(),
      end: current.end.toISOString(),
      isSingleDay: current.isSingleDay,
      timezone
    },
    summary: {
      ...currentMetrics,
      netSalesNote: "Net sales equals gross sales because discounts and refunds are not tracked in the current schema."
    },
    previousPeriod: {
      label: previous.label,
      start: previous.start.toISOString(),
      end: previous.end.toISOString(),
      ...previousMetrics
    },
    comparison: {
      grossSalesChangePct: calcPctChange(currentMetrics.grossSales, previousMetrics.grossSales),
      totalOrdersChangePct: calcPctChange(currentMetrics.totalOrders, previousMetrics.totalOrders),
      completedOrdersChangePct: calcPctChange(currentMetrics.completedOrders, previousMetrics.completedOrders),
      aovChangePct: calcPctChange(currentMetrics.averageOrderValue, previousMetrics.averageOrderValue)
    }
  };
}

export async function getAnalyticsOverviewController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const data = await computeOverviewData(timeframe, startDate, endDate, restaurantId);
    res.json(data);
  } catch (error) {
    console.error("Analytics Overview Error:", error);
    res.status(400).json({ error: error.message });
  }
}

/**
 * Computes sales timeline chart points (hourly or daily) scoped to restaurant.
 */
export async function computeSalesChartData(timeframe = "today", startDate = null, endDate = null, restaurantId = null) {
  const { current } = getISTDateRanges(timeframe, startDate, endDate);
  const grouping = current.isSingleDay ? "hourly" : "daily";
  const restFilter = getRestaurantFilter(restaurantId);

  const isRevenueExpression = {
    $and: [
      { $not: { $in: ["$status", ["Cancelled", "Payment Rejected"]] } },
      { $ne: ["$paymentStatus", "Rejected"] },
      {
        $or: [
          { $and: [{ $eq: ["$paymentMethod", "UPI"] }, { $eq: ["$paymentStatus", "Verified"] }] },
          { $in: ["$paymentMethod", ["COD", "Card"]] },
          { $in: ["$paymentMethod", [null, ""]] },
          { $eq: [{ $type: "$paymentMethod" }, "missing"] }
        ]
      }
    ]
  };

  if (grouping === "hourly") {
    const agg = await Order.aggregate([
      {
        $match: {
          createdAt: { $gte: current.start, $lte: current.end },
          ...restFilter
        }
      },
      {
        $project: {
          hour: { $hour: { date: "$createdAt", timezone: IST_TZ_STRING } },
          totalAmount: "$totalAmount",
          isRevenue: isRevenueExpression
        }
      },
      {
        $group: {
          _id: "$hour",
          ordersCount: { $sum: 1 },
          paidOrdersCount: { $sum: { $cond: ["$isRevenue", 1, 0] } },
          revenue: { $sum: { $cond: ["$isRevenue", "$totalAmount", 0] } }
        }
      }
    ]);

    const hourMap = new Map();
    agg.forEach(item => hourMap.set(item._id, item));

    const timeline = [];
    let totalRevenue = 0;
    let totalOrders = 0;

    for (let h = 0; h < 24; h++) {
      const data = hourMap.get(h) || { revenue: 0, ordersCount: 0, paidOrdersCount: 0 };
      totalRevenue += data.revenue;
      totalOrders += data.ordersCount;
      const hourStr = String(h).padStart(2, "0") + ":00";
      timeline.push({
        key: h,
        label: hourStr,
        revenue: data.revenue,
        ordersCount: data.ordersCount,
        paidOrdersCount: data.paidOrdersCount
      });
    }

    return {
      grouping: "hourly",
      rangeLabel: current.label,
      totalRevenue,
      totalOrders,
      timeline
    };
  } else {
    const agg = await Order.aggregate([
      {
        $match: {
          createdAt: { $gte: current.start, $lte: current.end },
          ...restFilter
        }
      },
      {
        $project: {
          dateStr: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt", timezone: IST_TZ_STRING } },
          totalAmount: "$totalAmount",
          isRevenue: isRevenueExpression
        }
      },
      {
        $group: {
          _id: "$dateStr",
          ordersCount: { $sum: 1 },
          paidOrdersCount: { $sum: { $cond: ["$isRevenue", 1, 0] } },
          revenue: { $sum: { $cond: ["$isRevenue", "$totalAmount", 0] } }
        }
      }
    ]);

    const dateMap = new Map();
    agg.forEach(item => dateMap.set(item._id, item));

    const timeline = [];
    let totalRevenue = 0;
    let totalOrders = 0;

    const startLocal = new Date(current.start.getTime() + IST_OFFSET_MS);
    const endLocal = new Date(current.end.getTime() + IST_OFFSET_MS);

    const cur = new Date(Date.UTC(startLocal.getUTCFullYear(), startLocal.getUTCMonth(), startLocal.getUTCDate()));
    const finalDate = new Date(Date.UTC(endLocal.getUTCFullYear(), endLocal.getUTCMonth(), endLocal.getUTCDate()));

    while (cur <= finalDate) {
      const year = cur.getUTCFullYear();
      const month = String(cur.getUTCMonth() + 1).padStart(2, "0");
      const day = String(cur.getUTCDate()).padStart(2, "0");
      const dateKey = `${year}-${month}-${day}`;

      const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      const displayLabel = `${day} ${monthNames[cur.getUTCMonth()]}`;

      const data = dateMap.get(dateKey) || { revenue: 0, ordersCount: 0, paidOrdersCount: 0 };
      totalRevenue += data.revenue;
      totalOrders += data.ordersCount;

      timeline.push({
        key: dateKey,
        label: displayLabel,
        revenue: data.revenue,
        ordersCount: data.ordersCount,
        paidOrdersCount: data.paidOrdersCount
      });

      cur.setUTCDate(cur.getUTCDate() + 1);
    }

    return {
      grouping: "daily",
      rangeLabel: current.label,
      totalRevenue,
      totalOrders,
      timeline
    };
  }
}

export async function getSalesChartController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const data = await computeSalesChartData(timeframe, startDate, endDate, restaurantId);
    res.json(data);
  } catch (error) {
    console.error("Sales Chart Error:", error);
    res.status(400).json({ error: error.message });
  }
}

/**
 * Computes order performance, statuses, and completion rates scoped to restaurant.
 */
export async function computeOrderPerformanceData(timeframe = "today", startDate = null, endDate = null, restaurantId = null) {
  const { current } = getISTDateRanges(timeframe, startDate, endDate);
  const restFilter = getRestaurantFilter(restaurantId);

  const results = await Order.aggregate([
    {
      $match: {
        createdAt: { $gte: current.start, $lte: current.end },
        ...restFilter
      }
    },
    {
      $facet: {
        statusCounts: [
          { $group: { _id: "$status", count: { $sum: 1 } } }
        ],
        paymentMethodCounts: [
          { $group: { _id: "$paymentMethod", count: { $sum: 1 }, totalAmount: { $sum: "$totalAmount" } } }
        ],
        prepTimes: [
          {
            $match: {
              status: { $in: ["Completed", "Collected"] }
            }
          },
          {
            $project: {
              durationMinutes: {
                $divide: [{ $subtract: ["$updatedAt", "$createdAt"] }, 60000]
              }
            }
          },
          {
            $match: { durationMinutes: { $gte: 0, $lte: 300 } }
          },
          {
            $group: {
              _id: null,
              avgMinutes: { $avg: "$durationMinutes" },
              count: { $sum: 1 }
            }
          }
        ],
        totalCount: [{ $count: "count" }]
      }
    }
  ]);

  const facet = results[0] || {};
  const totalOrders = facet.totalCount?.[0]?.count || 0;

  const statusMap = {
    Pending: 0,
    Processing: 0,
    Accepted: 0,
    Preparing: 0,
    Ready: 0,
    Completed: 0,
    Collected: 0,
    "Pending Verification": 0,
    "Payment Rejected": 0,
    Cancelled: 0
  };

  facet.statusCounts?.forEach(s => {
    if (statusMap[s._id] !== undefined) {
      statusMap[s._id] = s.count;
    } else {
      statusMap[s._id] = s.count;
    }
  });

  const completedCollected = (statusMap["Completed"] || 0) + (statusMap["Collected"] || 0);
  const cancelledRejected = (statusMap["Cancelled"] || 0) + (statusMap["Payment Rejected"] || 0);

  const completionRate = totalOrders > 0 ? Math.round((completedCollected / totalOrders) * 1000) / 10 : 0.0;
  const cancellationRate = totalOrders > 0 ? Math.round((cancelledRejected / totalOrders) * 1000) / 10 : 0.0;

  let upiCount = 0;
  let codCount = 0;
  let cardCount = 0;

  facet.paymentMethodCounts?.forEach(p => {
    if (p._id === "UPI") upiCount = p.count;
    else if (p._id === "Card") cardCount = p.count;
    else codCount += p.count;
  });

  const rawAvgPrep = facet.prepTimes?.[0]?.avgMinutes;
  const averagePrepTimeMinutes = rawAvgPrep != null ? Math.round(rawAvgPrep * 10) / 10 : null;

  return {
    totalOrders,
    statusBreakdown: statusMap,
    completionRate,
    cancellationRate,
    averagePrepTimeMinutes,
    prepTimeNote:
      "Average preparation time is estimated from order creation to collection for completed orders. Granular kitchen stage transitions are not tracked in the current schema.",
    paymentDistribution: {
      upi: { count: upiCount, percentage: totalOrders > 0 ? Math.round((upiCount / totalOrders) * 1000) / 10 : 0 },
      cod: { count: codCount, percentage: totalOrders > 0 ? Math.round((codCount / totalOrders) * 1000) / 10 : 0 },
      card: { count: cardCount, percentage: totalOrders > 0 ? Math.round((cardCount / totalOrders) * 1000) / 10 : 0 }
    }
  };
}

export async function getOrderPerformanceController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const data = await computeOrderPerformanceData(timeframe, startDate, endDate, restaurantId);
    res.json(data);
  } catch (error) {
    console.error("Order Performance Error:", error);
    res.status(400).json({ error: error.message });
  }
}

/**
 * Computes popular (best-selling) and underperforming menu items scoped to restaurant.
 */
export async function computePopularItemsData(timeframe = "today", startDate = null, endDate = null, sortBy = "quantity", restaurantId = null) {
  const { current } = getISTDateRanges(timeframe, startDate, endDate);
  const restFilter = getRestaurantFilter(restaurantId);

  const revenueFilter = getSuccessfulRevenueFilter();
  const soldItemsAgg = await Order.aggregate([
    {
      $match: {
        createdAt: { $gte: current.start, $lte: current.end },
        ...revenueFilter,
        ...restFilter
      }
    },
    { $unwind: "$orderItems" },
    {
      $group: {
        _id: "$orderItems.itemName",
        itemId: { $first: "$orderItems.itemId" },
        quantitySold: { $sum: "$orderItems.quantity" },
        salesValue: { $sum: { $multiply: ["$orderItems.itemPrice", "$orderItems.quantity"] } },
        orders: { $addToSet: "$_id" }
      }
    },
    {
      $project: {
        itemName: "$_id",
        itemId: 1,
        quantitySold: 1,
        salesValue: 1,
        ordersCount: { $size: "$orders" }
      }
    }
  ]);

  const itemQuery = restaurantId ? {
    $or: [
      { restaurantId: restaurantId },
      { restaurantId: { $exists: false } },
      { restaurantId: null }
    ]
  } : {};

  const menuItems = await Item.find(itemQuery).lean();
  const itemMetaMap = new Map();
  menuItems.forEach(item => {
    itemMetaMap.set(item.itemName.toLowerCase(), {
      category: item.category || "General",
      createdAt: item.createdAt,
      isAvailable: item.isAvailable
    });
  });

  const popularItems = soldItemsAgg.map(item => {
    const meta = itemMetaMap.get(item.itemName.toLowerCase());
    return {
      itemName: item.itemName,
      itemId: item.itemId,
      category: meta ? meta.category : "General",
      quantitySold: item.quantitySold,
      salesValue: item.salesValue,
      ordersCount: item.ordersCount
    };
  });

  if (sortBy === "salesValue") {
    popularItems.sort((a, b) => b.salesValue - a.salesValue);
  } else {
    popularItems.sort((a, b) => b.quantitySold - a.quantitySold);
  }

  const soldNameSet = new Set(popularItems.map(p => p.itemName.toLowerCase()));
  const now = new Date();
  const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);

  const underperformingItems = [];
  menuItems.forEach(item => {
    const isSold = soldNameSet.has(item.itemName.toLowerCase());
    if (!isSold) {
      const isNewlyAdded = item.createdAt && new Date(item.createdAt) > threeDaysAgo;
      underperformingItems.push({
        itemId: item._id,
        itemName: item.itemName,
        category: item.category,
        quantitySold: 0,
        salesValue: 0,
        isAvailable: item.isAvailable,
        status: isNewlyAdded ? "recently_added" : "zero_sales",
        statusLabel: isNewlyAdded ? "Recently Added" : "Zero Sales"
      });
    }
  });

  return {
    totalUniqueItemsSold: popularItems.length,
    popularItems,
    underperformingItems
  };
}

export async function getPopularItemsController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate, sortBy = "quantity" } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const data = await computePopularItemsData(timeframe, startDate, endDate, sortBy, restaurantId);
    res.json(data);
  } catch (error) {
    console.error("Popular Items Error:", error);
    res.status(400).json({ error: error.message });
  }
}

/**
 * Computes peak ordering hours & days of week scoped to restaurant.
 */
export async function computePeakHoursData(timeframe = "7d", startDate = null, endDate = null, restaurantId = null) {
  const { current } = getISTDateRanges(timeframe, startDate, endDate);
  const restFilter = getRestaurantFilter(restaurantId);

  const agg = await Order.aggregate([
    {
      $match: {
        createdAt: { $gte: current.start, $lte: current.end },
        ...restFilter
      }
    },
    {
      $facet: {
        byHour: [
          {
            $project: {
              hour: { $hour: { date: "$createdAt", timezone: IST_TZ_STRING } },
              totalAmount: "$totalAmount"
            }
          },
          {
            $group: {
              _id: "$hour",
              ordersCount: { $sum: 1 },
              volume: { $sum: "$totalAmount" }
            }
          }
        ],
        byDayOfWeek: [
          {
            $project: {
              dayOfWeek: { $dayOfWeek: { date: "$createdAt", timezone: IST_TZ_STRING } },
              totalAmount: "$totalAmount"
            }
          },
          {
            $group: {
              _id: "$dayOfWeek",
              ordersCount: { $sum: 1 },
              volume: { $sum: "$totalAmount" }
            }
          }
        ]
      }
    }
  ]);

  const facet = agg[0] || {};

  const hourMap = new Map();
  facet.byHour?.forEach(h => hourMap.set(h._id, h));

  const hourlyVolume = [];
  let peakHour = { hour: 0, label: "00:00", ordersCount: 0 };

  for (let h = 0; h < 24; h++) {
    const data = hourMap.get(h) || { ordersCount: 0, volume: 0 };
    const label = `${String(h).padStart(2, "0")}:00`;
    hourlyVolume.push({
      hour: h,
      label,
      ordersCount: data.ordersCount,
      volume: data.volume
    });
    if (data.ordersCount > peakHour.ordersCount) {
      peakHour = { hour: h, label, ordersCount: data.ordersCount };
    }
  }

  const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  const dayMap = new Map();
  facet.byDayOfWeek?.forEach(d => dayMap.set(d._id, d));

  const dayOfWeekVolume = [];
  let peakDay = { dayOfWeek: 1, dayName: "Sunday", ordersCount: 0 };

  for (let d = 1; d <= 7; d++) {
    const data = dayMap.get(d) || { ordersCount: 0, volume: 0 };
    const name = dayNames[d - 1];
    dayOfWeekVolume.push({
      dayOfWeek: d,
      dayName: name,
      ordersCount: data.ordersCount,
      volume: data.volume
    });
    if (data.ordersCount > peakDay.ordersCount) {
      peakDay = { dayOfWeek: d, dayName: name, ordersCount: data.ordersCount };
    }
  }

  return {
    hourlyVolume,
    dayOfWeekVolume,
    peakHour: peakHour.ordersCount > 0 ? peakHour : null,
    peakDay: peakDay.ordersCount > 0 ? peakDay : null
  };
}

export async function getPeakHoursController(req, res) {
  try {
    const { timeframe = "7d", startDate, endDate } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const data = await computePeakHoursData(timeframe, startDate, endDate, restaurantId);
    res.json(data);
  } catch (error) {
    console.error("Peak Hours Error:", error);
    res.status(400).json({ error: error.message });
  }
}

/**
 * Computes payment methods and verification stats scoped to restaurant.
 */
export async function computePaymentAnalyticsData(timeframe = "today", startDate = null, endDate = null, restaurantId = null) {
  const { current } = getISTDateRanges(timeframe, startDate, endDate);
  const restFilter = getRestaurantFilter(restaurantId);

  const agg = await Order.aggregate([
    {
      $match: {
        createdAt: { $gte: current.start, $lte: current.end },
        ...restFilter
      }
    },
    {
      $group: {
        _id: {
          method: "$paymentMethod",
          status: "$paymentStatus"
        },
        count: { $sum: 1 },
        amount: { $sum: "$totalAmount" }
      }
    }
  ]);

  const stats = {
    upi: {
      totalOrders: 0,
      totalAmount: 0,
      verifiedCount: 0,
      verifiedAmount: 0,
      pendingVerificationCount: 0,
      pendingVerificationAmount: 0,
      rejectedCount: 0,
      rejectedAmount: 0
    },
    cod: {
      totalOrders: 0,
      totalAmount: 0
    },
    card: {
      totalOrders: 0,
      totalAmount: 0
    }
  };

  agg.forEach(row => {
    const method = row._id.method || "COD";
    const status = row._id.status || (method === "UPI" ? "Awaiting Verification" : "Verified");

    if (method === "UPI") {
      stats.upi.totalOrders += row.count;
      stats.upi.totalAmount += row.amount;
      if (status === "Verified") {
        stats.upi.verifiedCount += row.count;
        stats.upi.verifiedAmount += row.amount;
      } else if (status === "Awaiting Verification" || status === "Pending") {
        stats.upi.pendingVerificationCount += row.count;
        stats.upi.pendingVerificationAmount += row.amount;
      } else if (status === "Rejected") {
        stats.upi.rejectedCount += row.count;
        stats.upi.rejectedAmount += row.amount;
      }
    } else if (method === "Card") {
      stats.card.totalOrders += row.count;
      stats.card.totalAmount += row.amount;
    } else {
      stats.cod.totalOrders += row.count;
      stats.cod.totalAmount += row.amount;
    }
  });

  const grandTotalOrders = stats.upi.totalOrders + stats.cod.totalOrders + stats.card.totalOrders;
  const verifiedRevenue = stats.upi.verifiedAmount + stats.cod.totalAmount + stats.card.totalAmount;

  return {
    summary: {
      grandTotalOrders,
      verifiedRevenue
    },
    upi: stats.upi,
    cod: stats.cod,
    card: stats.card,
    distribution: {
      upiOrderPct: grandTotalOrders > 0 ? Math.round((stats.upi.totalOrders / grandTotalOrders) * 1000) / 10 : 0,
      codOrderPct: grandTotalOrders > 0 ? Math.round((stats.cod.totalOrders / grandTotalOrders) * 1000) / 10 : 0,
      cardOrderPct: grandTotalOrders > 0 ? Math.round((stats.card.totalOrders / grandTotalOrders) * 1000) / 10 : 0
    }
  };
}

export async function getPaymentAnalyticsController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const data = await computePaymentAnalyticsData(timeframe, startDate, endDate, restaurantId);
    res.json(data);
  } catch (error) {
    console.error("Payment Analytics Error:", error);
    res.status(400).json({ error: error.message });
  }
}

export async function getAnalyticsDashboardController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate, sortBy = "quantity" } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;

    const [overview, sales, orders, items, peakHours, payments] = await Promise.all([
      computeOverviewData(timeframe, startDate, endDate, restaurantId),
      computeSalesChartData(timeframe, startDate, endDate, restaurantId),
      computeOrderPerformanceData(timeframe, startDate, endDate, restaurantId),
      computePopularItemsData(timeframe, startDate, endDate, sortBy, restaurantId),
      computePeakHoursData(timeframe, startDate, endDate, restaurantId),
      computePaymentAnalyticsData(timeframe, startDate, endDate, restaurantId)
    ]);

    res.json({
      overview,
      sales,
      orders,
      items,
      peakHours,
      payments
    });
  } catch (error) {
    console.error("Analytics Dashboard Error:", error);
    res.status(400).json({ error: error.message });
  }
}

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

export async function getAnalyticsExportController(req, res) {
  try {
    const { timeframe = "today", startDate, endDate } = req.query;
    const restaurantId = req.restaurantId || req.query.restaurantId;
    const { current } = getISTDateRanges(timeframe, startDate, endDate);
    const restFilter = getRestaurantFilter(restaurantId);

    const orders = await Order.find({
      createdAt: { $gte: current.start, $lte: current.end },
      ...restFilter
    }).lean();

    let grossSales = 0;
    let completedCount = 0;
    let cancelledCount = 0;
    let pendingCount = 0;
    let pendingUpiCount = 0;
    const itemSoldMap = {};
    const methodCounts = { UPI: 0, COD: 0, Card: 0 };
    const methodAmounts = { UPI: 0, COD: 0, Card: 0 };

    orders.forEach(order => {
      const isCancelled = ["Cancelled", "Payment Rejected"].includes(order.status);
      const isCompleted = ["Completed", "Collected"].includes(order.status);
      const isPending = ["Pending", "Processing", "Accepted", "Preparing", "Ready", "Pending Verification"].includes(order.status);

      if (isCompleted) completedCount++;
      if (isCancelled) cancelledCount++;
      if (isPending) pendingCount++;

      const isUpi = order.paymentMethod === "UPI";
      const isVerifiedRevenue =
        !isCancelled &&
        order.paymentStatus !== "Rejected" &&
        (!isUpi || order.paymentStatus === "Verified");

      if (isUpi && order.paymentStatus === "Awaiting Verification") {
        pendingUpiCount++;
      }

      const methodKey = order.paymentMethod || "COD";
      if (methodCounts[methodKey] !== undefined) {
        methodCounts[methodKey]++;
      } else {
        methodCounts.COD++;
      }

      if (isVerifiedRevenue) {
        grossSales += order.totalAmount || 0;
        if (methodAmounts[methodKey] !== undefined) {
          methodAmounts[methodKey] += order.totalAmount || 0;
        } else {
          methodAmounts.COD += order.totalAmount || 0;
        }

        (order.orderItems || []).forEach(item => {
          if (!itemSoldMap[item.itemName]) {
            itemSoldMap[item.itemName] = { quantity: 0, salesValue: 0, orders: 0 };
          }
          itemSoldMap[item.itemName].quantity += item.quantity || 1;
          itemSoldMap[item.itemName].salesValue += (item.itemPrice || 0) * (item.quantity || 1);
          itemSoldMap[item.itemName].orders += 1;
        });
      }
    });

    const totalOrders = orders.length;
    const aov = grossSales > 0 && (completedCount + pendingCount) > 0 ? Math.round(grossSales / (completedCount + pendingCount)) : 0;

    const lines = [];

    lines.push(`"SERVEO RESTAURANT ANALYTICS REPORT"`);
    lines.push(`"Timeframe","${current.label}"`);
    lines.push(`"Start (IST)","${new Date(current.start.getTime() + IST_OFFSET_MS).toISOString().replace("T", " ").substring(0, 19)}"`);
    lines.push(`"End (IST)","${new Date(current.end.getTime() + IST_OFFSET_MS).toISOString().replace("T", " ").substring(0, 19)}"`);
    lines.push(`"Generated At","${new Date().toISOString()}"`);
    lines.push("");

    lines.push(`"EXECUTIVE SUMMARY"`);
    lines.push(`"Metric","Value"`);
    lines.push(`"Gross Sales (INR)",${grossSales}`);
    lines.push(`"Net Sales (INR)",${grossSales}`);
    lines.push(`"Total Orders Placed",${totalOrders}`);
    lines.push(`"Completed / Collected Orders",${completedCount}`);
    lines.push(`"Pending / In Kitchen Orders",${pendingCount}`);
    lines.push(`"Cancelled / Rejected Orders",${cancelledCount}`);
    lines.push(`"Average Order Value (INR)",${aov}`);
    lines.push(`"Pending UPI Verifications",${pendingUpiCount}`);
    lines.push("");

    lines.push(`"PAYMENT SUMMARY"`);
    lines.push(`"Payment Method","Order Count","Verified Revenue (INR)"`);
    lines.push(`"UPI",${methodCounts.UPI},${methodAmounts.UPI}`);
    lines.push(`"Cash on Delivery (COD)",${methodCounts.COD},${methodAmounts.COD}`);
    lines.push(`"Card",${methodCounts.Card},${methodAmounts.Card}`);
    lines.push("");

    lines.push(`"MENU ITEM PERFORMANCE"`);
    lines.push(`"Item Name","Quantity Sold","Sales Value (INR)","Order Appearances"`);

    const sortedItems = Object.entries(itemSoldMap).sort((a, b) => b[1].quantity - a[1].quantity);
    if (sortedItems.length === 0) {
      lines.push(`"No items sold during this period",0,0,0`);
    } else {
      sortedItems.forEach(([name, data]) => {
        lines.push(`${sanitizeCsvCell(name)},${data.quantity},${data.salesValue},${data.orders}`);
      });
    }

    const csvContent = lines.join("\r\n");

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="serveo-analytics-${timeframe.replace(/[^a-zA-Z0-9_-]/g, "_")}.csv"`
    );
    res.status(200).send(csvContent);
  } catch (error) {
    console.error("Analytics Export Error:", error);
    res.status(400).json({ error: error.message });
  }
}
