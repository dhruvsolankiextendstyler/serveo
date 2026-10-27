import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_analytics_provider.dart';

void main() {
  test('Parse exact live payloads from Render backend', () {
    // 1. Overview payload from live server
    const overviewJsonStr = '''{
  "selectedRange": {
    "timeframe": "today",
    "label": "Today",
    "start": "2026-10-26T18:30:00.000Z",
    "end": "2026-10-27T18:29:59.999Z",
    "isSingleDay": true,
    "timezone": "Asia/Kolkata"
  },
  "summary": {
    "grossSales": 356,
    "netSales": 356,
    "totalOrders": 2,
    "completedOrders": 2,
    "pendingOrders": 0,
    "cancelledOrders": 0,
    "averageOrderValue": 178,
    "pendingUpiVerifications": 0,
    "netSalesNote": "Net sales equals gross sales because discounts and refunds are not tracked in the current schema."
  },
  "previousPeriod": {
    "label": "Previous Period",
    "start": "2026-10-25T18:30:00.000Z",
    "end": "2026-10-26T18:29:59.999Z",
    "grossSales": 0,
    "netSales": 0,
    "totalOrders": 7,
    "completedOrders": 7,
    "pendingOrders": 0,
    "cancelledOrders": 0,
    "averageOrderValue": 0,
    "pendingUpiVerifications": 0
  },
  "comparison": {
    "grossSalesChangePct": null,
    "totalOrdersChangePct": -71.4,
    "completedOrdersChangePct": -71.4,
    "aovChangePct": null
  }
}''';

    // 2. Sales payload
    const salesJsonStr = '''{
  "grouping": "hourly",
  "rangeLabel": "Today",
  "totalRevenue": 356,
  "totalOrders": 2,
  "timeline": [
    {
      "key": "2026-10-27 00:00",
      "label": "00:00",
      "revenue": 0,
      "ordersCount": 0,
      "paidOrdersCount": 0
    },
    {
      "key": "2026-10-27 19:00",
      "label": "19:00",
      "revenue": 356,
      "ordersCount": 2,
      "paidOrdersCount": 2
    }
  ]
}''';

    // 3. Orders payload
    const ordersJsonStr = '''{
  "totalOrders": 2,
  "statusBreakdown": {
    "Pending": 0,
    "Processing": 0,
    "Accepted": 0,
    "Preparing": 0,
    "Ready": 0,
    "Completed": 0,
    "Collected": 2,
    "Pending Verification": 0,
    "Payment Rejected": 0,
    "Cancelled": 0
  },
  "completionRate": 100,
  "cancellationRate": 0,
  "averagePrepTimeMinutes": null,
  "prepTimeNote": "Average preparation time is estimated from order creation to collection for completed orders. Granular kitchen stage transitions are not tracked in the current schema.",
  "paymentDistribution": {
    "upi": {
      "count": 1,
      "percentage": 50
    },
    "cod": {
      "count": 1,
      "percentage": 50
    },
    "card": {
      "count": 0,
      "percentage": 0
    }
  }
}''';

    // 4. Items payload
    const itemsJsonStr = '''{
  "totalUniqueItemsSold": 1,
  "popularItems": [
    {
      "itemName": "Veggie Crunch Burger",
      "itemId": "6ad8cc2026351aad0e94af8d",
      "quantitySold": 4,
      "salesValue": 356,
      "ordersCount": 2,
      "category": "Burgers"
    }
  ],
  "underperformingItems": [
    {
      "itemId": "6ad8cc2026351aad0e94af91",
      "itemName": "Classic Cheese Burger",
      "category": "Burgers",
      "quantitySold": 0,
      "salesValue": 0,
      "isAvailable": true,
      "status": "zero_sales",
      "statusLabel": "Zero Sales"
    }
  ]
}''';

    // 5. Peak hours payload
    const peakHoursJsonStr = '''{
  "hourlyVolume": [
    {
      "hour": 0,
      "label": "00:00",
      "ordersCount": 0,
      "volume": 0
    }
  ],
  "dayOfWeekVolume": [
    {
      "dayOfWeek": 1,
      "dayName": "Sunday",
      "ordersCount": 0,
      "volume": 0
    }
  ],
  "peakHour": {
    "hour": 19,
    "label": "19:00",
    "ordersCount": 2
  },
  "peakDay": {
    "dayOfWeek": 3,
    "dayName": "Tuesday",
    "ordersCount": 2
  }
}''';

    // 6. Payments payload
    const paymentsJsonStr = '''{
  "summary": {
    "grandTotalOrders": 2,
    "verifiedRevenue": 356
  },
  "upi": {
    "totalOrders": 1,
    "totalAmount": 178,
    "verifiedCount": 1,
    "verifiedAmount": 178,
    "pendingVerificationCount": 0,
    "pendingVerificationAmount": 0,
    "rejectedCount": 0,
    "rejectedAmount": 0
  },
  "cod": {
    "totalOrders": 1,
    "totalAmount": 178
  },
  "card": {
    "totalOrders": 0,
    "totalAmount": 0
  },
  "distribution": {
    "upiOrderPct": 50,
    "codOrderPct": 50,
    "cardOrderPct": 0
  }
}''';

    final overview = AnalyticsOverview.fromJson(jsonDecode(overviewJsonStr));
    expect(overview.grossSales, 356);

    final sales = SalesTimeline.fromJson(jsonDecode(salesJsonStr));
    expect(sales.totalRevenue, 356);

    final orders = OrderPerformance.fromJson(jsonDecode(ordersJsonStr));
    expect(orders.totalOrders, 2);

    final items = ItemInsights.fromJson(jsonDecode(itemsJsonStr));
    expect(items.totalUniqueItemsSold, 1);

    final peak = PeakHoursData.fromJson(jsonDecode(peakHoursJsonStr));
    expect(peak.peakHour?.hour, 19);

    final payments = PaymentAnalytics.fromJson(jsonDecode(paymentsJsonStr));
    expect(payments.verifiedRevenue, 356);
  });
}
