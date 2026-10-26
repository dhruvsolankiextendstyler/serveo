import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/admin_widgets/admin_history_page.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Order History Display Tests', () {
    test('AdminOrder.parsedOrderItems extracts items and quantities accurately', () {
      final order = AdminOrder(
        id: '507f1f77bcf86cd799439011',
        uid: 'user_123',
        orderItems: [
          {'itemName': 'Paneer Sandwich', 'quantity': 2, 'itemPrice': 120},
          {'itemName': 'Cold Coffee', 'quantity': 1, 'itemPrice': 80},
          {'itemName': 'Veg Burger', 'quantity': 1, 'itemPrice': 90},
        ],
        orderDate: '2026-10-27 00:30',
        totalAmount: 410,
        status: 'Collected',
        customerName: 'Rahul Sharma',
        paymentMethod: 'COD',
        paymentStatus: 'Pending',
        createdAt: DateTime.parse('2026-10-26T19:00:00.000Z'), // 00:30 IST next day
      );

      final items = order.parsedOrderItems;
      expect(items.length, 3);
      expect(items[0]['itemName'], 'Paneer Sandwich');
      expect(items[0]['quantity'], 2);
      expect(items[0]['itemPrice'], 120);

      expect(items[1]['itemName'], 'Cold Coffee');
      expect(items[1]['quantity'], 1);

      expect(items[2]['itemName'], 'Veg Burger');
      expect(items[2]['quantity'], 1);

      // Verify Asia/Kolkata date format (UTC 19:00 + 5:30 = 00:30 AM Oct 27)
      expect(order.formattedDateTimeKolkata, contains('27 Oct 2026'));
      expect(order.formattedDateTimeKolkata, contains('12:30 AM'));
    });

    test('AdminOrder handles legacy orders with missing customer and string items gracefully', () {
      final legacyOrder = AdminOrder(
        id: 'legacy_999',
        uid: 'old_uid',
        orderItems: [
          'Simple Samosa',
        ],
        orderDate: '2026-10-20 12:00',
        totalAmount: 40,
        status: 'Completed',
      );

      expect(legacyOrder.customerName, 'Customer');
      final items = legacyOrder.parsedOrderItems;
      expect(items.length, 1);
      expect(items[0]['itemName'], 'Simple Samosa');
      expect(items[0]['quantity'], 1);
    });

    testWidgets('HistoryPage renders order cards with items, quantities, totals, and timestamps', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockOrders = [
        AdminOrder(
          id: '671abc12345',
          uid: 'user_456',
          orderItems: [
            {'itemName': 'Paneer Sandwich', 'quantity': 2, 'itemPrice': 120},
            {'itemName': 'Cold Coffee', 'quantity': 1, 'itemPrice': 80},
          ],
          orderDate: '2026-10-27 00:30',
          totalAmount: 320,
          status: 'Collected',
          customerName: 'Aman Patel',
          paymentMethod: 'COD',
          paymentStatus: 'Pending',
          createdAt: DateTime.parse('2026-10-26T19:00:00.000Z'),
        ),
      ];

      final provider = AdminOrderProvider();
      // Inject orders into provider for testing
      provider.orders.addAll(mockOrders);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AdminOrderProvider>.value(
              value: provider,
              child: const HistoryPage(),
            ),
          ),
        ),
      );

      // Verify order ID snippet
      expect(find.textContaining('Order #'), findsOneWidget);

      // Verify food items with quantities
      expect(find.textContaining('Paneer Sandwich × 2'), findsOneWidget);
      expect(find.textContaining('Cold Coffee × 1'), findsOneWidget);

      // Verify Total formatted in INR
      expect(find.text('Total: ₹320'), findsOneWidget);

      // Verify Placed timestamp in Asia/Kolkata
      expect(find.textContaining('Placed: 27 Oct 2026'), findsOneWidget);

      // Verify status badge
      expect(find.text('Collected'), findsWidgets);

      // Verify payment details
      expect(find.text('Payment: COD'), findsOneWidget);

      // Verify customer name
      expect(find.text('Aman Patel'), findsOneWidget);
    });

    testWidgets('HistoryPage displays empty state when no historical orders exist', (tester) async {
      final emptyProvider = AdminOrderProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AdminOrderProvider>.value(
              value: emptyProvider,
              child: const HistoryPage(),
            ),
          ),
        ),
      );

      expect(find.text('No Order History Found'), findsOneWidget);
    });
  });
}
