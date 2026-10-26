import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/admin_widgets/admin_order_card.dart';
import 'package:frontend/admin_widgets/admin_order_details.dart';
import 'package:frontend/pages/upi_qr_payment_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/payment_config.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminOrder Customer & Payment Parsing Tests', () {
    test('Correctly parses full customerDetails and UPI payment verification fields', () {
      final json = {
        '_id': 'ord_upi_123456',
        'userId': {
          '_id': 'usr_999',
          'fullName': 'John Doe',
          'phoneNumber': '9876543210',
          'email': 'john@example.com',
        },
        'customerDetails': {
          'fullName': 'John Doe',
          'phoneNumber': '9876543210',
          'email': 'john@example.com',
        },
        'orderItems': [
          {'itemId': 'item1', 'itemName': 'Veggie Crunch Burger', 'itemPrice': 89, 'quantity': 2},
          {'itemId': 'item2', 'itemName': 'Cold Coffee', 'itemPrice': 79, 'quantity': 1},
        ],
        'totalAmount': 257,
        'status': 'Processing',
        'paymentMethod': 'UPI',
        'paymentStatus': 'Awaiting Verification',
        'paymentClaimedAt': '2026-10-26T14:00:00.000Z',
        'createdAt': '2026-10-26T13:58:00.000Z',
      };

      final order = AdminOrder.fromJson(json);

      expect(order.id, 'ord_upi_123456');
      expect(order.customerName, 'John Doe');
      expect(order.customerPhone, '9876543210');
      expect(order.customerEmail, 'john@example.com');
      expect(order.isUpi, isTrue);
      expect(order.isCod, isFalse);
      expect(order.isAwaitingVerification, isTrue);
      expect(order.totalAmount, 257);
      expect(order.paymentClaimedAt, isNotNull);
      expect(order.formattedClaimTime, isNotEmpty);
    });

    test('Gracefully handles older legacy orders without customerDetails or paymentMethod', () {
      final legacyJson = {
        '_id': 'legacy_order_111',
        'userId': 'simple_user_id_string',
        'orderItems': [
          {'itemId': 'item1', 'itemName': 'Punjabi Samosa', 'itemPrice': 40, 'quantity': 2},
        ],
        'totalAmount': 80,
        'status': 'Processing',
      };

      final order = AdminOrder.fromJson(legacyJson);

      expect(order.id, 'legacy_order_111');
      expect(order.customerName, 'Customer');
      expect(order.customerPhone, 'N/A');
      expect(order.customerEmail, 'N/A');
      expect(order.isCod, isTrue); // Defaults to COD for backwards compatibility
      expect(order.isUpi, isFalse);
      expect(order.isAwaitingVerification, isFalse);
    });

    test('Parses verified order details with verifier email and verification timestamp', () {
      final verifiedJson = {
        '_id': 'ord_verified_222',
        'userId': 'usr_888',
        'customerDetails': {
          'fullName': 'Alice Smith',
          'phoneNumber': '9123456789',
          'email': 'alice@example.com',
        },
        'orderItems': [],
        'totalAmount': 159,
        'status': 'Preparing',
        'paymentMethod': 'UPI',
        'paymentStatus': 'Verified',
        'paymentClaimedAt': '2026-10-26T14:00:00.000Z',
        'paymentVerifiedAt': '2026-10-26T14:02:00.000Z',
        'verifiedBy': 'admin123@ad.in',
      };

      final order = AdminOrder.fromJson(verifiedJson);

      expect(order.isVerified, isTrue);
      expect(order.isAwaitingVerification, isFalse);
      expect(order.verifiedBy, 'admin123@ad.in');
      expect(order.paymentVerifiedAt, isNotNull);
      expect(order.formattedVerifiedTime, isNotEmpty);
    });
  });

  group('UpiQrPaymentPage Widget Tests', () {
    testWidgets('Displays order number, exact total, setup message, and instructions', (tester) async {
      final testOrder = Order(
        id: 'ord_test_9999',
        totalAmount: 299,
        status: 'Processing',
        orderDate: '2026-10-26 14:00',
        orderItems: [
          {'itemId': 'item1', 'itemName': 'Farmhouse Veggie Pizza', 'itemPrice': 189, 'quantity': 1},
          {'itemId': 'item2', 'itemName': 'Cold Coffee', 'itemPrice': 79, 'quantity': 1},
        ],
        paymentMethod: 'UPI',
        paymentStatus: 'Pending',
      );

      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: MaterialApp(
            home: UpiQrPaymentPage(order: testOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Heading and manual verification notice
      expect(find.text("UPI Payment (Manual)"), findsOneWidget);
      expect(find.text("Manual Payment Verification"), findsOneWidget);

      // Order number and exact validated amount
      expect(find.text("Order #9999"), findsOneWidget);
      expect(find.text("₹299"), findsOneWidget);

      // Since QR is unconfigured by default, displays setup message
      if (!PaymentConfig.isConfigured) {
        expect(find.text("Merchant UPI QR Not Configured"), findsOneWidget);
      }

      // Step-by-step instructions
      expect(find.text("PAYMENT INSTRUCTIONS"), findsOneWidget);
      expect(find.textContaining("Transfer exact payable amount: ₹299"), findsOneWidget);

      // Action button
      expect(find.text("I've completed the payment"), findsOneWidget);
      expect(find.text("Pay Later / Track in Orders"), findsOneWidget);
    });
  });

  group('AdminOrderCard Widget Tests', () {
    testWidgets('Displays VERIFY UPI badge and customer details for pending UPI orders', (tester) async {
      final pendingUpiOrder = AdminOrder(
        id: 'ord_upi_5555',
        uid: 'usr1',
        orderItems: [
          {'itemName': 'Veg Burger', 'itemPrice': 89, 'quantity': 1}
        ],
        orderDate: '2026-10-26 14:00',
        totalAmount: 89,
        status: 'Processing',
        customerName: 'Rahul Sharma',
        customerPhone: '9898989898',
        customerEmail: 'rahul@example.com',
        paymentMethod: 'UPI',
        paymentStatus: 'Awaiting Verification',
      );

      final adminOrderProvider = AdminOrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminOrderProvider>.value(value: adminOrderProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AdminOrderCard(order: pendingUpiOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Order #5555"), findsOneWidget);
      expect(find.text("VERIFY UPI"), findsOneWidget);
      expect(find.text("Rahul Sharma"), findsOneWidget);
      expect(find.text("9898989898"), findsOneWidget);
      expect(find.text("UPI (Unverified)"), findsOneWidget);
    });

    testWidgets('Displays COD badge for cash orders', (tester) async {
      final codOrder = AdminOrder(
        id: 'ord_cod_6666',
        uid: 'usr2',
        orderItems: [
          {'itemName': 'Punjabi Samosa', 'itemPrice': 40, 'quantity': 2}
        ],
        orderDate: '2026-10-26 14:00',
        totalAmount: 80,
        status: 'Processing',
        customerName: 'Priya Patel',
        customerPhone: '9797979797',
        paymentMethod: 'COD',
        paymentStatus: 'Pending',
      );

      final adminOrderProvider = AdminOrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminOrderProvider>.value(value: adminOrderProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AdminOrderCard(order: codOrder),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Order #6666"), findsOneWidget);
      expect(find.text("COD"), findsOneWidget);
      expect(find.text("Priya Patel"), findsOneWidget);
      expect(find.text("VERIFY UPI"), findsNothing);
    });
  });

  group('AdminOrderDetailsPage Details & Verification Actions Tests', () {
    testWidgets('Displays customer information, order items, and verification buttons for pending UPI', (tester) async {
      final pendingOrder = AdminOrder(
        id: '65f1a2b3c4d5e6f7a8b9c0d1',
        uid: 'usr_xyz',
        orderItems: [
          {'itemName': 'Paneer Tikka Pizza', 'itemPrice': 219, 'quantity': 1},
          {'itemName': 'Lemon Iced Tea', 'itemPrice': 59, 'quantity': 2},
        ],
        orderDate: '2026-10-26 14:00',
        totalAmount: 337,
        status: 'Processing',
        customerName: 'Vikram Malhotra',
        customerPhone: '9988776655',
        customerEmail: 'vikram@example.com',
        paymentMethod: 'UPI',
        paymentStatus: 'Awaiting Verification',
        paymentClaimedAt: DateTime.parse('2026-10-26T14:05:00.000Z'),
      );

      final adminOrderProvider = AdminOrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminOrderProvider>.value(value: adminOrderProvider),
          ],
          child: MaterialApp(
            home: AdminOrderDetailsPage(order: pendingOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Customer info section
      expect(find.text("CUSTOMER INFORMATION"), findsOneWidget);
      expect(find.text("Vikram Malhotra"), findsOneWidget);
      expect(find.text("9988776655"), findsOneWidget);
      expect(find.text("vikram@example.com"), findsOneWidget);

      // Payment section
      expect(find.text("PAYMENT INFORMATION"), findsOneWidget);
      expect(find.text("UPI (GPay / PhonePe / QR)"), findsOneWidget);
      expect(find.text("Awaiting Verification"), findsOneWidget);

      // Items and bill totals
      expect(find.text("Paneer Tikka Pizza"), findsOneWidget);
      expect(find.text("Lemon Iced Tea"), findsOneWidget);
      expect(find.text("₹337"), findsWidgets);

      // Action buttons: Confirm and Reject buttons MUST be present
      expect(find.text("Confirm Payment Received"), findsOneWidget);
      expect(find.text("Payment Not Received / Reject Claim"), findsOneWidget);
      // ACCEPT & COOK should NOT be shown before verification
      expect(find.text("ACCEPT & COOK"), findsNothing);
    });

    testWidgets('Displays COD details without QR controls and shows ACCEPT & COOK', (tester) async {
      final codOrder = AdminOrder(
        id: '65f1a2b3c4d5e6f7a8b9c0d2',
        uid: 'usr_abc',
        orderItems: [
          {'itemName': 'Crispy French Fries', 'itemPrice': 69, 'quantity': 1},
        ],
        orderDate: '2026-10-26 14:00',
        totalAmount: 69,
        status: 'Processing',
        customerName: 'Karan Mehra',
        customerPhone: '9111223344',
        customerEmail: 'karan@example.com',
        paymentMethod: 'COD',
        paymentStatus: 'Pending',
      );

      final adminOrderProvider = AdminOrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminOrderProvider>.value(value: adminOrderProvider),
          ],
          child: MaterialApp(
            home: AdminOrderDetailsPage(order: codOrder),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // COD payment method displayed
      expect(find.text("Cash on Delivery (COD)"), findsOneWidget);

      // Standard preparation workflow action
      expect(find.text("ACCEPT & COOK"), findsOneWidget);

      // Verification buttons MUST NOT be shown for COD
      expect(find.text("Confirm Payment Received"), findsNothing);
      expect(find.text("Payment Not Received / Reject Claim"), findsNothing);
    });
  });

  group('AdminOrderProvider Verification State & Polling Deduplication Tests', () {
    test('Dismissing alert prevents repeated popups without removing pending verification request', () {
      final provider = AdminOrderProvider();

      final order1 = AdminOrder(
        id: 'ord_1',
        uid: 'usr1',
        orderItems: [],
        orderDate: '2026-10-26 14:00',
        totalAmount: 100,
        status: 'Processing',
        paymentMethod: 'UPI',
        paymentStatus: 'Awaiting Verification',
      );

      // Simulate order arrives
      provider.orders.add(order1);

      // Outstanding verification requests
      expect(provider.pendingVerificationOrders.length, 1);
      expect(provider.pendingVerificationOrders.first.id, 'ord_1');

      // Dismiss alert for ord_1
      provider.dismissAlert('ord_1');
      expect(provider.pendingAlertOrder, isNull);

      // Request remains in outstanding verifications
      expect(provider.pendingVerificationOrders.length, 1);
    });
  });

  group('PaymentConfig UPI Intent & QR Generator Tests', () {
    test('PaymentConfig.getPaymentIntentUri returns null when upiId is unconfigured', () {
      expect(PaymentConfig.getPaymentIntentUri(orderId: '123', amount: 100), isNull);
    });

    test('PaymentConfig.getQrUrlForOrder returns null when unconfigured without custom network URL', () {
      expect(PaymentConfig.getQrUrlForOrder(orderId: '123', amount: 100), isNull);
    });
  });

  group('OrderProvider UPI Payment Initiation & Error Handling Tests', () {
    test('Rejects placeOrder when order tray is empty without calling backend', () async {
      final orderProvider = OrderProvider();
      bool called = false;
      final mockClient = MockOrderHttpClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'mock_token',
      );

      expect(order, isNull);
      expect(called, isFalse);
      expect(orderProvider.lastOrderError, 'Your order tray is empty.');
    });

    test('Rejects placeOrder when user is unauthenticated', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '1', itemName: 'Burger', itemPrice: 100, category: 'Food'));
      bool called = false;
      final mockClient = MockOrderHttpClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
      );

      expect(order, isNull);
      expect(called, isFalse);
      expect(orderProvider.lastOrderError, 'Please sign in to place your order.');
      // Cart items MUST be preserved
      expect(orderProvider.orderItems.length, 1);
    });

    test('Successfully initiates UPI payment with modern backend format and clears tray', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '101', itemName: 'Paneer Wrap', itemPrice: 150, category: 'Wraps'));
      expect(orderProvider.getTotal(), 150);

      final mockClient = MockOrderHttpClient((request) async {
        expect(request.url.path, '/order/add');
        expect(request.headers['Authorization'], 'Bearer valid_test_token');
        return http.Response(
          jsonEncode({
            'message': 'Order Placed !!',
            'order': {
              '_id': 'ord_modern_999',
              'totalAmount': 150,
              'status': 'Processing',
              'paymentMethod': 'UPI',
              'paymentStatus': 'Pending',
              'createdAt': '2026-10-26T14:30:00.000Z',
              'orderItems': [
                {'itemId': '101', 'itemName': 'Paneer Wrap', 'itemPrice': 150, 'quantity': 1}
              ],
            }
          }),
          201,
        );
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'valid_test_token',
      );

      expect(order, isNotNull);
      expect(order!.id, 'ord_modern_999');
      expect(order.totalAmount, 150);
      expect(order.paymentMethod, 'UPI');
      expect(order.paymentStatus, 'Pending');
      expect(orderProvider.lastOrderError, isNull);
      // Tray cleared upon confirmed order placement
      expect(orderProvider.orderItems.isEmpty, isTrue);
    });

    test('Successfully initiates UPI payment with legacy response ({ message: "Order Placed !!" }) without failing', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '202', itemName: 'Thali', itemPrice: 200, category: 'Meals'));

      final mockClient = MockOrderHttpClient((request) async {
        if (request.url.path == '/order/add') {
          // Deployed server returns only message
          return http.Response(jsonEncode({'message': 'Order Placed !!'}), 201);
        } else if (request.url.path == '/order/user') {
          return http.Response(
            jsonEncode({
              'message': [
                {
                  '_id': 'ord_legacy_resolved_123',
                  'totalAmount': 200,
                  'status': 'Processing',
                  'paymentMethod': 'UPI',
                  'paymentStatus': 'Pending',
                  'createdAt': '2026-10-26T14:35:00.000Z',
                  'orderItems': [
                    {'itemId': '202', 'itemName': 'Thali', 'itemPrice': 200, 'quantity': 1}
                  ],
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'valid_token_legacy',
      );

      expect(order, isNotNull);
      expect(order!.id, 'ord_legacy_resolved_123');
      expect(order.totalAmount, 200);
      expect(order.paymentMethod, 'UPI');
      expect(orderProvider.lastOrderError, isNull);
      expect(orderProvider.orderItems.isEmpty, isTrue);
    });

    test('Preserves customer cart and sets descriptive error when server returns 401 Unauthorized', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '303', itemName: 'Biryani', itemPrice: 220, category: 'Rice'));

      final mockClient = MockOrderHttpClient((request) async {
        return http.Response(jsonEncode({'message': 'Access denied No token'}), 401);
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'expired_or_invalid_token',
      );

      expect(order, isNull);
      expect(orderProvider.lastOrderError, 'Authentication failed. Please sign in again.');
      // Customer tray is NOT cleared so they can sign in and retry!
      expect(orderProvider.orderItems.length, 1);
      expect(orderProvider.orderItems.first.itemName, 'Biryani');
    });

    test('Preserves customer cart and displays specific server error when backend returns 400 Bad Request', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '404', itemName: 'Pizza', itemPrice: 299, category: 'Pizza'));

      final mockClient = MockOrderHttpClient((request) async {
        return http.Response(jsonEncode({'error': 'Item out of stock: Pizza'}), 400);
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'valid_token',
      );

      expect(order, isNull);
      expect(orderProvider.lastOrderError, 'Item out of stock: Pizza');
      expect(orderProvider.orderItems.length, 1);
    });

    test('Preserves customer cart and displays server unavailable message when backend returns 500', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '505', itemName: 'Sandwich', itemPrice: 80, category: 'Snacks'));

      final mockClient = MockOrderHttpClient((request) async {
        return http.Response(jsonEncode({'error': 'Internal server error'}), 500);
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'valid_token',
      );

      expect(order, isNull);
      expect(orderProvider.lastOrderError, 'Server is temporarily unavailable. Please try again shortly.');
      expect(orderProvider.orderItems.length, 1);
    });

    test('Preserves customer cart and displays friendly message on network timeout', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '606', itemName: 'Cold Drink', itemPrice: 40, category: 'Beverages'));

      final mockClient = MockOrderHttpClient((request) async {
        throw TimeoutException('Simulated timeout during cold start');
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'valid_token',
      );

      expect(order, isNull);
      expect(orderProvider.lastOrderError, contains('Server took too long to respond'));
      expect(orderProvider.orderItems.length, 1);
    });

    test('Preserves customer cart and displays connection message on network failure', () async {
      final orderProvider = OrderProvider();
      orderProvider.addToCart(Item(itemId: '707', itemName: 'Noodles', itemPrice: 110, category: 'Chinese'));

      final mockClient = MockOrderHttpClient((request) async {
        throw http.ClientException('Failed host lookup');
      });

      final order = await orderProvider.placeOrder(
        paymentMethod: 'UPI',
        client: mockClient,
        overrideToken: 'valid_token',
      );

      expect(order, isNull);
      expect(orderProvider.lastOrderError, 'Unable to connect to server. Please check your internet connection.');
      expect(orderProvider.orderItems.length, 1);
    });
  });
}

class MockOrderHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  MockOrderHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}
