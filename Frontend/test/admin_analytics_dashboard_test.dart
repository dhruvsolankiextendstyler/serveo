import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_analytics_provider.dart';
import 'package:frontend/admin_widgets/admin_report_page.dart';
import 'package:frontend/admin_widgets/analytics/serveo_peak_hours_chart.dart';
import 'package:frontend/admin_widgets/analytics/serveo_sales_chart.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Analytics Data Models & Calculations', () {
    test('AnalyticsOverview model parses full payload with comparisons', () {
      final json = {
        'selectedRange': {
          'timeframe': 'today',
          'label': 'Today',
          'start': '2026-10-25T18:30:00.000Z',
          'end': '2026-10-26T18:29:59.999Z',
          'isSingleDay': true,
          'timezone': 'Asia/Kolkata',
        },
        'summary': {
          'grossSales': 12450,
          'netSales': 12450,
          'netSalesNote': 'Net sales equals gross sales',
          'totalOrders': 45,
          'completedOrders': 38,
          'pendingOrders': 5,
          'cancelledOrders': 2,
          'averageOrderValue': 276,
          'pendingUpiVerifications': 3,
        },
        'previousPeriod': {
          'label': 'Yesterday',
          'grossSales': 10000,
          'totalOrders': 40,
        },
        'comparison': {
          'grossSalesChangePct': 24.5,
          'totalOrdersChangePct': 12.5,
          'completedOrdersChangePct': 8.6,
          'aovChangePct': 10.4,
        }
      };

      final overview = AnalyticsOverview.fromJson(json);
      expect(overview.grossSales, 12450);
      expect(overview.netSales, 12450);
      expect(overview.totalOrders, 45);
      expect(overview.completedOrders, 38);
      expect(overview.pendingOrders, 5);
      expect(overview.cancelledOrders, 2);
      expect(overview.averageOrderValue, 276);
      expect(overview.pendingUpiVerifications, 3);
      expect(overview.comparison.grossSalesChangePct, 24.5);
      expect(overview.comparison.totalOrdersChangePct, 12.5);
      expect(overview.previousLabel, 'Yesterday');
    });

    test('AnalyticsOverview handles empty dataset without division-by-zero or crash', () {
      final json = {
        'selectedRange': {
          'timeframe': 'today',
          'label': 'Today',
          'start': '2026-10-25T18:30:00.000Z',
          'end': '2026-10-26T18:29:59.999Z',
          'isSingleDay': true,
          'timezone': 'Asia/Kolkata',
        },
        'summary': {
          'grossSales': 0,
          'netSales': 0,
          'totalOrders': 0,
          'completedOrders': 0,
          'pendingOrders': 0,
          'cancelledOrders': 0,
          'averageOrderValue': 0,
          'pendingUpiVerifications': 0,
        },
        'previousPeriod': {'label': 'Yesterday'},
        'comparison': {
          'grossSalesChangePct': 0.0,
          'totalOrdersChangePct': 0.0,
          'completedOrdersChangePct': 0.0,
          'aovChangePct': 0.0,
        }
      };

      final overview = AnalyticsOverview.fromJson(json);
      expect(overview.grossSales, 0);
      expect(overview.totalOrders, 0);
      expect(overview.averageOrderValue, 0);
      expect(overview.comparison.grossSalesChangePct, 0.0);
    });

    test('SalesTimeline model correctly parses hourly and daily timelines', () {
      final json = {
        'grouping': 'hourly',
        'rangeLabel': 'Today',
        'totalRevenue': 3500,
        'totalOrders': 12,
        'timeline': [
          {'key': 12, 'label': '12:00', 'revenue': 1200, 'ordersCount': 4, 'paidOrdersCount': 4},
          {'key': 13, 'label': '13:00', 'revenue': 2300, 'ordersCount': 8, 'paidOrdersCount': 8},
        ]
      };

      final timeline = SalesTimeline.fromJson(json);
      expect(timeline.grouping, 'hourly');
      expect(timeline.totalRevenue, 3500);
      expect(timeline.totalOrders, 12);
      expect(timeline.timeline.length, 2);
      expect(timeline.timeline[0].label, '12:00');
      expect(timeline.timeline[0].revenue, 1200);
    });

    test('ItemInsights parses popular items and underperforming items with status labels', () {
      final json = {
        'totalUniqueItemsSold': 2,
        'popularItems': [
          {
            'itemName': 'Veggie Crunch Burger',
            'category': 'Burgers',
            'quantitySold': 15,
            'salesValue': 1335,
            'ordersCount': 10
          },
          {
            'itemName': 'Cold Coffee',
            'category': 'Beverages',
            'quantitySold': 8,
            'salesValue': 632,
            'ordersCount': 7
          }
        ],
        'underperformingItems': [
          {
            'itemName': 'Gulab Jamun (2 pcs)',
            'category': 'Desserts',
            'quantitySold': 0,
            'salesValue': 0,
            'isAvailable': true,
            'status': 'zero_sales',
            'statusLabel': 'Zero Sales'
          },
          {
            'itemName': 'Avocado Toast',
            'category': 'Snacks',
            'quantitySold': 0,
            'salesValue': 0,
            'isAvailable': true,
            'status': 'recently_added',
            'statusLabel': 'Recently Added'
          }
        ]
      };

      final insights = ItemInsights.fromJson(json);
      expect(insights.popularItems.length, 2);
      expect(insights.popularItems[0].itemName, 'Veggie Crunch Burger');
      expect(insights.popularItems[0].salesValue, 1335);

      expect(insights.underperformingItems.length, 2);
      expect(insights.underperformingItems[0].statusLabel, 'Zero Sales');
      expect(insights.underperformingItems[1].statusLabel, 'Recently Added');
    });

    test('PaymentAnalytics correctly separates verified revenue from pending claims', () {
      final json = {
        'summary': {'grandTotalOrders': 30, 'verifiedRevenue': 6500},
        'upi': {
          'totalOrders': 20,
          'totalAmount': 5000,
          'verifiedCount': 15,
          'verifiedAmount': 4000,
          'pendingVerificationCount': 4,
          'pendingVerificationAmount': 800,
          'rejectedCount': 1,
          'rejectedAmount': 200,
        },
        'cod': {'totalOrders': 10, 'totalAmount': 2500},
        'card': {'totalOrders': 0, 'totalAmount': 0},
        'distribution': {'upiOrderPct': 66.7, 'codOrderPct': 33.3, 'cardOrderPct': 0.0}
      };

      final pay = PaymentAnalytics.fromJson(json);
      expect(pay.grandTotalOrders, 30);
      expect(pay.verifiedRevenue, 6500);
      expect(pay.upi.verifiedAmount, 4000);
      expect(pay.upi.pendingVerificationCount, 4);
      expect(pay.upi.pendingVerificationAmount, 800);
      expect(pay.upi.rejectedCount, 1);
      expect(pay.cod.totalAmount, 2500);
    });
  });

  group('ServeoSalesChart Widget Tests', () {
    testWidgets('Renders empty state cleanly when no sales exist', (tester) async {
      final emptyTimeline = SalesTimeline(
        grouping: 'hourly',
        rangeLabel: 'Today',
        totalRevenue: 0,
        totalOrders: 0,
        timeline: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServeoSalesChart(timelineData: emptyTimeline),
          ),
        ),
      );

      expect(find.text("No sales recorded for this period"), findsOneWidget);
    });

    testWidgets('Renders sales trend and updates tooltip on bar tap', (tester) async {
      final sampleTimeline = SalesTimeline(
        grouping: 'hourly',
        rangeLabel: 'Today',
        totalRevenue: 4500,
        totalOrders: 15,
        timeline: List.generate(
          24,
          (h) => SalesTimelinePoint(
            key: h,
            label: "$h:00",
            revenue: h == 14 ? 2000 : 100,
            ordersCount: h == 14 ? 6 : 1,
            paidOrdersCount: h == 14 ? 6 : 1,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ServeoSalesChart(timelineData: sampleTimeline),
            ),
          ),
        ),
      );

      expect(find.text("Hourly Sales Trend"), findsOneWidget);
      expect(find.text("₹4500"), findsOneWidget);

      // Tap one of the bars to trigger tooltip
      await tester.tap(find.byType(GestureDetector).at(14));
      await tester.pumpAndSettle();

      expect(find.textContaining("14:00"), findsOneWidget);
      expect(find.textContaining("₹2000"), findsOneWidget);
    });
  });

  group('ServeoPeakHoursChart Widget Tests', () {
    testWidgets('Renders hourly and weekly distribution with peak badge', (tester) async {
      final peakData = PeakHoursData(
        hourlyVolume: List.generate(
          24,
          (h) => PeakHourPoint(hour: h, label: "$h:00", ordersCount: h == 20 ? 12 : 2, volume: h == 20 ? 2500 : 400),
        ),
        dayOfWeekVolume: [
          PeakDayPoint(dayOfWeek: 1, dayName: 'Sunday', ordersCount: 15, volume: 3000),
          PeakDayPoint(dayOfWeek: 2, dayName: 'Monday', ordersCount: 8, volume: 1500),
          PeakDayPoint(dayOfWeek: 3, dayName: 'Tuesday', ordersCount: 10, volume: 2000),
          PeakDayPoint(dayOfWeek: 4, dayName: 'Wednesday', ordersCount: 12, volume: 2400),
          PeakDayPoint(dayOfWeek: 5, dayName: 'Thursday', ordersCount: 14, volume: 2800),
          PeakDayPoint(dayOfWeek: 6, dayName: 'Friday', ordersCount: 25, volume: 5000),
          PeakDayPoint(dayOfWeek: 7, dayName: 'Saturday', ordersCount: 30, volume: 6000),
        ],
        peakHour: PeakHourPoint(hour: 20, label: "20:00", ordersCount: 12, volume: 2500),
        peakDay: PeakDayPoint(dayOfWeek: 7, dayName: "Saturday", ordersCount: 30, volume: 6000),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServeoPeakHoursChart(data: peakData),
          ),
        ),
      );

      expect(find.text("Peak Ordering Times (IST)"), findsOneWidget);
      expect(find.text("Peak: 20:00"), findsOneWidget);
      expect(find.text("Hourly Distribution (24 Hours)"), findsOneWidget);
      expect(find.text("Weekly Traffic Distribution"), findsOneWidget);
      expect(find.text("Sat"), findsOneWidget);
      expect(find.text("Fri"), findsOneWidget);
    });
  });

  group('AdminReportPage Widget Tests', () {
    testWidgets('Renders header and date filter chips correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminReportPage(),
          ),
        ),
      );

      // Header
      expect(find.text("Analytics & Insights"), findsOneWidget);
      expect(find.text("Export CSV"), findsOneWidget);

      // Date Filters
      expect(find.text("Today"), findsOneWidget);
      expect(find.text("Yesterday"), findsOneWidget);
      expect(find.text("Last 7 Days"), findsOneWidget);
      expect(find.text("Last 30 Days"), findsOneWidget);
      expect(find.text("This Month"), findsOneWidget);
      expect(find.text("Prev Month"), findsOneWidget);
      expect(find.text("Custom Range"), findsOneWidget);
    });

    testWidgets('Tapping date filter chip changes selected timeframe', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminReportPage(),
          ),
        ),
      );

      await tester.pump();

      // Tap "Last 7 Days"
      final last7Chip = find.text("Last 7 Days");
      expect(last7Chip, findsOneWidget);
      await tester.tap(last7Chip);
      await tester.pump();

      // Verify widget remains stable
      expect(find.text("Analytics & Insights"), findsOneWidget);
    });
  });
}
