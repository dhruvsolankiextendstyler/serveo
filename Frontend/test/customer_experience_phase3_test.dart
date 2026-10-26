import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pages/order_history_page.dart';
import 'package:frontend/pages/order_tracking_page.dart';
import 'package:frontend/utils/menu_provider.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Catalog
  final sampleCatalog = [
    Item(
      itemId: "item_burger_1",
      itemName: "Veggie Crunch Burger",
      itemPrice: 99, // Current price updated from 89
      category: "Burgers",
      description: "Crispy mixed vegetable patty with lettuce",
      isAvailable: true,
      isVeg: true,
      dietary: "Veg",
    ),
    Item(
      itemId: "item_burger_2",
      itemName: "Chicken Zinger Burger",
      itemPrice: 149,
      category: "Burgers",
      description: "Crispy fried chicken breast",
      isAvailable: true,
      isVeg: false,
      dietary: "Non-Veg",
    ),
    Item(
      itemId: "item_bev_1",
      itemName: "Cold Coffee",
      itemPrice: 79,
      category: "Beverages",
      description: "Chilled blended coffee with chocolate drizzle",
      isAvailable: false, // Sold Out
      isVeg: true,
      dietary: "Veg",
    ),
    Item(
      itemId: "item_snack_1",
      itemName: "French Fries",
      itemPrice: 69,
      category: "Snacks",
      description: "Salted golden potato fries",
      isAvailable: true,
      isVeg: true,
      dietary: "Veg",
    ),
  ];

  group('Phase 3 — Part 1: Live Order Tracking Tests', () {
    testWidgets('OrderTrackingPage renders details, timeline, and items cleanly', (tester) async {
      final sampleOrder = Order(
        id: "66f4001b9a2c3d4e5f607182",
        totalAmount: 267,
        status: "Preparing",
        orderDate: "2026-10-26 18:30",
        paymentMethod: "COD",
        paymentStatus: "Pending",
        orderItems: [
          {"itemId": "item_burger_1", "itemName": "Veggie Crunch Burger", "itemPrice": 89, "quantity": 2},
          {"itemId": "item_bev_1", "itemName": "Cold Coffee", "itemPrice": 89, "quantity": 1},
        ],
      );

      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: OrderTrackingPage(
              orderId: sampleOrder.id,
              initialOrder: sampleOrder,
            ),
          ),
        ),
      );

      // Verify Header and Order ID
      expect(find.text("Track Order #7182"), findsOneWidget);
      expect(find.textContaining("607182"), findsOneWidget);
      expect(find.text("PREPARING"), findsOneWidget);

      // Verify Timeline Stages
      expect(find.text("Live Order Progress"), findsOneWidget);
      expect(find.text("Order Placed"), findsOneWidget);
      expect(find.text("Order Accepted"), findsOneWidget);
      expect(find.text("Preparing Food"), findsOneWidget);
      expect(find.text("Ready for Pickup"), findsOneWidget);
      expect(find.text("Collected"), findsOneWidget);

      // Verify Items Breakdown
      expect(find.text("Veggie Crunch Burger"), findsOneWidget);
      expect(find.text("Cold Coffee"), findsOneWidget);
      expect(find.text("₹89 × 2"), findsOneWidget);
      expect(find.text("₹267"), findsWidgets);

      // Verify Navigation Options
      expect(find.text("Order History"), findsOneWidget);
      expect(find.text("Back to Menu"), findsOneWidget);
    });

    testWidgets('OrderTrackingPage displays distinct UPI Verification step', (tester) async {
      final upiPendingOrder = Order(
        id: "66f4001b9a2c3d4e5f609999",
        totalAmount: 189,
        status: "Pending Verification",
        orderDate: "2026-10-26 18:45",
        paymentMethod: "UPI",
        paymentStatus: "Awaiting Verification",
        orderItems: [
          {"itemId": "item_burger_1", "itemName": "Veggie Crunch Burger", "itemPrice": 89, "quantity": 1},
        ],
      );

      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: OrderTrackingPage(
              orderId: upiPendingOrder.id,
              initialOrder: upiPendingOrder,
            ),
          ),
        ),
      );

      // Distinct UPI Verification stage must be visible
      expect(find.text("Awaiting UPI Verification"), findsOneWidget);
      expect(find.textContaining("Manager is verifying your payment declaration"), findsOneWidget);
    });

    testWidgets('OrderTrackingPage displays pickup receipt button when Ready', (tester) async {
      final readyOrder = Order(
        id: "66f4001b9a2c3d4e5f608888",
        totalAmount: 189,
        status: "Ready",
        orderDate: "2026-10-26 18:50",
        paymentMethod: "COD",
        paymentStatus: "Pending",
        orderItems: [
          {"itemId": "item_burger_1", "itemName": "Veggie Crunch Burger", "itemPrice": 89, "quantity": 1},
        ],
      );

      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: OrderTrackingPage(
              orderId: readyOrder.id,
              initialOrder: readyOrder,
            ),
          ),
        ),
      );

      expect(find.text("Your Food is Ready at Counter!"), findsOneWidget);
      expect(find.text("SHOW PICKUP RECEIPT"), findsOneWidget);
    });

    testWidgets('OrderTrackingPage displays terminal cancellation banner on cancelled order', (tester) async {
      final cancelledOrder = Order(
        id: "66f4001b9a2c3d4e5f607777",
        totalAmount: 150,
        status: "Cancelled",
        orderDate: "2026-10-26 19:00",
        paymentMethod: "COD",
        orderItems: [],
      );

      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: OrderTrackingPage(
              orderId: cancelledOrder.id,
              initialOrder: cancelledOrder,
            ),
          ),
        ),
      );

      expect(find.text("Order Cancelled"), findsOneWidget);
      expect(find.textContaining("This order has been cancelled"), findsOneWidget);
    });
  });

  group('Phase 3 — Part 2: Order History and Reorder Tests', () {
    test('OrderProvider reorderOrder validates against current catalog and prices', () {
      final orderProvider = OrderProvider();

      final historicalOrder = Order(
        id: "hist_123",
        totalAmount: 237,
        status: "Completed",
        orderDate: "2026-10-20 12:00",
        orderItems: [
          {"itemId": "item_burger_1", "itemName": "Veggie Crunch Burger", "itemPrice": 89, "quantity": 1}, // Price changed: 89 -> 99
          {"itemId": "item_bev_1", "itemName": "Cold Coffee", "itemPrice": 79, "quantity": 1},           // Sold Out
          {"itemId": "deleted_id", "itemName": "Discontinued Pizza", "itemPrice": 199, "quantity": 1},   // Discontinued
        ],
      );

      final result = orderProvider.reorderOrder(historicalOrder, sampleCatalog);

      // 1. Only available item added
      expect(result.addedItems.length, 1);
      expect(result.addedItems[0].itemName, "Veggie Crunch Burger");
      expect(result.addedItems[0].currentPrice, 99); // Current catalog price, NOT 89!

      // 2. Cart updated with current catalog price
      expect(orderProvider.orderItems.length, 1);
      expect(orderProvider.orderItems[0].itemName, "Veggie Crunch Burger");
      expect(orderProvider.orderItems[0].itemPrice, 99);
      expect(orderProvider.getTotal(), 99);

      // 3. Sold out & deleted items flagged
      expect(result.unavailableItems.length, 2);
      expect(result.unavailableItems.any((u) => u.contains("Cold Coffee")), true);
      expect(result.unavailableItems.any((u) => u.contains("Discontinued Pizza")), true);

      // 4. Price change detected
      expect(result.priceChanges.length, 1);
      expect(result.priceChanges[0].oldPrice, 89);
      expect(result.priceChanges[0].newPrice, 99);
    });

    testWidgets('OrderHistoryPage renders order card with Track Order and Reorder buttons', (tester) async {
      final orderProvider = OrderProvider();
      final menuProvider = MenuProvider();

      final sampleOrder = Order(
        id: "66f4001b9a2c3d4e5f601234",
        totalAmount: 198,
        status: "Completed",
        orderDate: "2026-10-26 15:00",
        paymentMethod: "UPI",
        paymentStatus: "Verified",
        orderItems: [
          {"itemId": "item_burger_1", "itemName": "Veggie Crunch Burger", "itemPrice": 99, "quantity": 2},
        ],
      );

      // Inject order
      orderProvider.myOrders.add(sampleOrder);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<MenuProvider>.value(value: menuProvider),
          ],
          child: const MaterialApp(
            home: OrderHistoryPage(),
          ),
        ),
      );

      expect(find.text("My Orders"), findsOneWidget);
      expect(find.text("Order #1234"), findsOneWidget);
      expect(find.text("2× Veggie Crunch Burger"), findsOneWidget);
      expect(find.text("Total: ₹198"), findsOneWidget);

      // Both actions must be available
      expect(find.text("Track Order"), findsOneWidget);
      expect(find.text("Reorder"), findsOneWidget);
    });
  });

  group('Phase 3 — Part 3: Menu Search & Filters Tests', () {
    test('Case-insensitive search matches name, description, and category', () {
      final query = "coffee";
      final matched = sampleCatalog.where((it) {
        final q = query.toLowerCase();
        return it.itemName.toLowerCase().contains(q) ||
            (it.description ?? "").toLowerCase().contains(q) ||
            it.category.toLowerCase().contains(q);
      }).toList();

      expect(matched.length, 1);
      expect(matched[0].itemName, "Cold Coffee");
    });

    test('Dietary filter separates Veg from Non-Veg', () {
      final vegItems = sampleCatalog.where((it) => it.isVeg).toList();
      final nonVegItems = sampleCatalog.where((it) => !it.isVeg).toList();

      expect(vegItems.length, 3);
      expect(nonVegItems.length, 1);
      expect(nonVegItems[0].itemName, "Chicken Zinger Burger");
    });

    test('Availability filter hides sold-out items', () {
      final inStockItems = sampleCatalog.where((it) => it.isAvailable).toList();
      expect(inStockItems.length, 3);
      expect(inStockItems.any((it) => it.itemName == "Cold Coffee"), false);
    });

    test('Combined filter: Category (Burgers) + Dietary (Veg) + InStock', () {
      final filtered = sampleCatalog.where((it) {
        if (it.category != "Burgers") return false;
        if (!it.isVeg) return false;
        if (!it.isAvailable) return false;
        return true;
      }).toList();

      expect(filtered.length, 1);
      expect(filtered[0].itemName, "Veggie Crunch Burger");
    });

    test('Sorting by price Low-to-High and High-to-Low', () {
      final ascending = List<Item>.from(sampleCatalog)..sort((a, b) => a.itemPrice.compareTo(b.itemPrice));
      expect(ascending.first.itemPrice, 69);
      expect(ascending.last.itemPrice, 149);

      final descending = List<Item>.from(sampleCatalog)..sort((a, b) => b.itemPrice.compareTo(a.itemPrice));
      expect(descending.first.itemPrice, 149);
      expect(descending.last.itemPrice, 69);
    });
  });
}
