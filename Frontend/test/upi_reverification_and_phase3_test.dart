import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/pages/digital_receipt_page.dart';
import 'package:frontend/pages/order_history_page.dart';
import 'package:frontend/pages/order_tracking_page.dart';
import 'package:frontend/pages/upi_qr_payment_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:frontend/widgets/breakbite_cart_item_card.dart';
import 'package:frontend/widgets/breakbite_food_card.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part A — Payment Re-Verification Customer Flow', () {
    testWidgets('OrderTrackingPage renders Payment Verification Rejected banner and Re-submit CTA', (tester) async {
      final rejectedOrder = Order(
        id: "66f4001b9a2c3d4e5f607999",
        totalAmount: 349,
        status: "Payment Rejected",
        orderDate: "2026-10-28 10:30",
        paymentMethod: "UPI",
        paymentStatus: "Rejected",
        paymentRejectionReason: "UTR mismatch - amount not credited",
        verificationAttempts: [
          {
            "attemptNumber": 1,
            "submittedAt": "2026-10-28T10:31:00.000Z",
            "status": "Rejected",
            "reviewedAt": "2026-10-28T10:35:00.000Z",
            "reviewedBy": "Admin",
            "rejectionReason": "UTR mismatch - amount not credited",
          }
        ],
        orderItems: [
          {"itemId": "item_pizza_1", "itemName": "Margherita Pizza", "itemPrice": 349, "quantity": 1},
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
              orderId: rejectedOrder.id,
              initialOrder: rejectedOrder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Rejection Banner and Admin Reason
      expect(find.text("Payment Verification Rejected"), findsWidgets);
      expect(find.textContaining("UTR mismatch - amount not credited"), findsWidgets);
      expect(find.text("Request Verification Again"), findsOneWidget);

      // Verify guidance message
      expect(
        find.textContaining("If the money was not received or the amount was incorrect"),
        findsOneWidget,
      );
    });

    testWidgets('UpiQrPaymentPage shows rejection context, exact amount, and re-submission CTA', (tester) async {
      final rejectedOrder = Order(
        id: "66f4001b9a2c3d4e5f607999",
        totalAmount: 349,
        status: "Payment Rejected",
        orderDate: "2026-10-28 10:30",
        paymentMethod: "UPI",
        paymentStatus: "Rejected",
        paymentRejectionReason: "Incorrect amount transferred (Received ₹300 instead of ₹349)",
        orderItems: [
          {"itemId": "item_pizza_1", "itemName": "Margherita Pizza", "itemPrice": 349, "quantity": 1},
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
            home: UpiQrPaymentPage(order: rejectedOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Rejection Alert Banner in UPI Payment screen
      expect(find.text("Previous Verification Rejected"), findsOneWidget);
      expect(find.textContaining("Incorrect amount transferred"), findsOneWidget);
      expect(find.textContaining("₹349"), findsWidgets);
      expect(find.text("Submit Verification Again"), findsOneWidget);
    });

    testWidgets('OrderHistoryPage displays rejection status and Re-submit button', (tester) async {
      final rejectedOrder = Order(
        id: "66f4001b9a2c3d4e5f607999",
        totalAmount: 180,
        status: "Payment Rejected",
        orderDate: "2026-10-28 11:00",
        paymentMethod: "UPI",
        paymentStatus: "Rejected",
        paymentRejectionReason: "Payment not received",
        orderItems: [
          {"itemId": "item_burger_1", "itemName": "Cheese Burger", "itemPrice": 180, "quantity": 1},
        ],
      );

      final orderProvider = OrderProvider();
      orderProvider.myOrders.add(rejectedOrder);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: OrderHistoryPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Re-submit Payment for Verification"), findsOneWidget);
      expect(find.text("View Digital Receipt"), findsOneWidget);
      expect(find.textContaining("Reason: Payment not received"), findsOneWidget);
    });
  });

  group('Part A — Admin Re-Verification Auditable Model & Polling Deduplication', () {
    test('AdminOrder model parses verification attempts history and identifies resubmission', () {
      final orderJson = {
        "_id": "66f4001b9a2c3d4e5f607111",
        "userId": {"_id": "user123", "fullName": "Rohan Sharma"},
        "orderItems": [{"itemName": "Masala Dosa", "itemPrice": 120, "quantity": 1}],
        "totalAmount": 120,
        "status": "Pending Verification",
        "paymentMethod": "UPI",
        "paymentStatus": "Awaiting Verification",
        "verificationAttempts": [
          {
            "attemptNumber": 1,
            "submittedAt": "2026-10-28T09:00:00.000Z",
            "status": "Rejected",
            "reviewedAt": "2026-10-28T09:05:00.000Z",
            "reviewedBy": "manager@serveo.com",
            "rejectionReason": "Bank server down",
          },
          {
            "attemptNumber": 2,
            "submittedAt": "2026-10-28T09:15:00.000Z",
            "status": "Pending",
          }
        ],
        "estimatedPrepTime": 20,
      };

      final adminOrder = AdminOrder.fromJson(orderJson);

      expect(adminOrder.id, "66f4001b9a2c3d4e5f607111");
      expect(adminOrder.attemptCount, 2);
      expect(adminOrder.isResubmitted, true);
      expect(adminOrder.isAwaitingVerification, true);
      expect(adminOrder.verificationAttempts.length, 2);
      expect(adminOrder.verificationAttempts[0]['rejectionReason'], "Bank server down");
      expect(adminOrder.latestAttempt?['status'], "Pending");
      expect(adminOrder.estimatedPrepTime, 20);
    });
  });

  group('Part B — Feature 1: Estimated Kitchen Preparation Time', () {
    testWidgets('OrderTrackingPage renders dynamic estimated preparation time', (tester) async {
      final activeOrder = Order(
        id: "66f4001b9a2c3d4e5f607222",
        totalAmount: 250,
        status: "Preparing",
        orderDate: "2026-10-28 11:15",
        paymentMethod: "UPI",
        paymentStatus: "Verified",
        estimatedPrepTime: 18,
        estimatedReadyAt: DateTime.parse("2026-10-28T11:45:00.000Z"),
        orderItems: [
          {"itemId": "item_pasta_1", "itemName": "Alfredo Pasta", "itemPrice": 250, "quantity": 1},
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
              orderId: activeOrder.id,
              initialOrder: activeOrder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Estimated Ready Time"), findsOneWidget);
      expect(find.text("ESTIMATE"), findsOneWidget);
      expect(find.textContaining("~18 mins"), findsOneWidget);
    });
  });

  group('Part B — Feature 3: Food Item Customizations', () {
    test('Item and Tray calculations support add-ons, sizes, and cartKey isolation', () {
      final pizza = Item(
        itemId: "item_pizza_custom",
        itemName: "Farmhouse Pizza",
        itemPrice: 249,
        category: "Pizza",
        customizations: [
          CustomizationGroup(
            name: "Size",
            type: "single",
            required: true,
            options: [
              CustomizationOption(name: "Regular (7\")", price: 0),
              CustomizationOption(name: "Medium (10\")", price: 120),
              CustomizationOption(name: "Large (12\")", price: 220),
            ],
          ),
          CustomizationGroup(
            name: "Add-ons",
            type: "multiple",
            required: false,
            options: [
              CustomizationOption(name: "Extra Cheese", price: 50),
              CustomizationOption(name: "Jalapenos", price: 30),
            ],
          ),
        ],
      );

      expect(pizza.hasCustomizations, true);
      expect(pizza.effectiveUnitPrice, 249); // Base price without choices

      // Customize Item: Medium (+120) + Extra Cheese (+50)
      final customizedMedium = pizza.copyWith(
        selectedCustomizations: [
          SelectedCustomization(customizationName: "Size", optionName: "Medium (10\")", price: 120),
          SelectedCustomization(customizationName: "Add-ons", optionName: "Extra Cheese", price: 50),
        ],
      );

      expect(customizedMedium.customizationsTotal, 170);
      expect(customizedMedium.effectiveUnitPrice, 419); // 249 + 170
      expect(customizedMedium.cartKey, contains("Size=Medium (10\")"));
      expect(customizedMedium.cartKey, contains("Add-ons=Extra Cheese"));

      // Add to OrderProvider tray
      final orderProvider = OrderProvider();
      orderProvider.addToCart(customizedMedium);

      expect(orderProvider.orderItems.length, 1);
      expect(orderProvider.getTotal(), 419);

      // Adding the same customization increments quantity
      orderProvider.addToCart(customizedMedium);
      expect(orderProvider.orderItems.length, 1);
      expect(orderProvider.orderItems.first.quantity, 2);
      expect(orderProvider.getTotal(), 838);

      // Adding a different customization creates a distinct cart entry
      final customizedLarge = pizza.copyWith(
        selectedCustomizations: [
          SelectedCustomization(customizationName: "Size", optionName: "Large (12\")", price: 220),
        ],
      );
      orderProvider.addToCart(customizedLarge);
      expect(orderProvider.orderItems.length, 2);
      expect(orderProvider.getTotal(), 838 + 469); // 838 + (249 + 220)
    });

    testWidgets('CartItemCard renders customization labels and effective subtotal', (tester) async {
      final customizedItem = Item(
        itemId: "item_burger_custom",
        itemName: "Gourmet Burger",
        itemPrice: 150,
        category: "Burgers",
        selectedCustomizations: [
          SelectedCustomization(customizationName: "Size", optionName: "Double Patty", price: 60),
          SelectedCustomization(customizationName: "Add-ons", optionName: "Cheese Slice", price: 25),
        ],
      )..quantity = 2;

      final orderProvider = OrderProvider();
      orderProvider.addToCart(customizedItem);
      orderProvider.addToCart(customizedItem); // quantity becomes 2

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CartItemCard(item: orderProvider.orderItems.first),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Gourmet Burger"), findsOneWidget);
      expect(find.textContaining("Double Patty (+₹60)"), findsOneWidget);
      expect(find.textContaining("Cheese Slice (+₹25)"), findsOneWidget);
      // Effective price = (150 + 85) * 2 = 470
      expect(find.text("₹470"), findsOneWidget);
    });
  });

  group('Part B — Feature 4: Digital Receipts and Customer Feedback', () {
    testWidgets('DigitalReceiptPage renders itemized breakdown, non-fake badge, and copy action', (tester) async {
      final verifiedOrder = Order(
        id: "66f4001b9a2c3d4e5f607444",
        totalAmount: 399,
        status: "Completed",
        orderDate: "2026-10-28 11:30",
        paymentMethod: "UPI",
        paymentStatus: "Verified",
        orderItems: [
          {
            "itemName": "Paneer Tikka Pizza",
            "quantity": 1,
            "itemPrice": 399,
            "selectedCustomizations": [
              {"customizationName": "Size", "optionName": "Medium", "price": 80},
              {"customizationName": "Crust", "optionName": "Cheese Burst", "price": 70},
            ]
          }
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DigitalReceiptPage(
            orderId: verifiedOrder.id,
            items: verifiedOrder.orderItems,
            order: verifiedOrder,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and store brand
      expect(find.text("SERVEO DINING"), findsOneWidget);
      expect(find.text("PAID (UPI VERIFIED)"), findsOneWidget);
      expect(find.text("ITEMIZED BREAKDOWN"), findsOneWidget);
      expect(find.text("Paneer Tikka Pizza × 1"), findsOneWidget);
      expect(find.textContaining("Medium (+₹80)"), findsOneWidget);
      expect(find.textContaining("Cheese Burst (+₹70)"), findsOneWidget);
      expect(find.text("Grand Total"), findsOneWidget);
      expect(find.text("₹399"), findsWidgets);

      // Verify Copy Action exists
      expect(find.text("Copy Text Summary"), findsOneWidget);
    });

    testWidgets('DigitalReceiptPage never labels unverified UPI payment as paid', (tester) async {
      final unverifiedOrder = Order(
        id: "66f4001b9a2c3d4e5f607555",
        totalAmount: 200,
        status: "Pending Verification",
        orderDate: "2026-10-28 11:40",
        paymentMethod: "UPI",
        paymentStatus: "Awaiting Verification",
        orderItems: [
          {"itemName": "Pasta", "quantity": 1, "itemPrice": 200}
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DigitalReceiptPage(
            orderId: unverifiedOrder.id,
            items: unverifiedOrder.orderItems,
            order: unverifiedOrder,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure it displays AWAITING VERIFICATION, NOT PAID
      expect(find.text("AWAITING VERIFICATION"), findsOneWidget);
      expect(find.text("PAID (UPI VERIFIED)"), findsNothing);
    });

    testWidgets('OrderTrackingPage renders feedback card for Completed orders', (tester) async {
      final completedOrder = Order(
        id: "66f4001b9a2c3d4e5f607666",
        totalAmount: 150,
        status: "Completed",
        orderDate: "2026-10-28 12:00",
        paymentMethod: "COD",
        paymentStatus: "Verified",
        orderItems: [
          {"itemId": "item_1", "itemName": "Dosa", "itemPrice": 150, "quantity": 1},
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
              orderId: completedOrder.id,
              initialOrder: completedOrder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify feedback prompt is present on completed order
      expect(find.text("How was your meal?"), findsOneWidget);
      expect(find.text("Submit Feedback"), findsOneWidget);
      expect(find.text("Delicious"), findsOneWidget);
      expect(find.text("Hot & Fresh"), findsOneWidget);
    });
  });
}
