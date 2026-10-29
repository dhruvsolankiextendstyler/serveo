import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/admin_widgets/admin_page.dart';
import 'package:frontend/admin_widgets/admin_settings_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/restaurant_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase 5 — Staff Accounts & Subscription Models', () {
    test('StaffMember model parses JSON correctly', () {
      final json = {
        '_id': 'staff_123',
        'email': 'chef@restaurant.com',
        'name': 'Chef Gordon',
        'role': 'kitchen',
        'isActive': true,
        'addedAt': '2026-10-29T10:00:00.000Z',
      };

      final staff = StaffMember.fromJson(json);
      expect(staff.id, 'staff_123');
      expect(staff.email, 'chef@restaurant.com');
      expect(staff.name, 'Chef Gordon');
      expect(staff.role, 'kitchen');
      expect(staff.isActive, isTrue);
    });

    test('SubscriptionInfo model parses plan details and limits correctly', () {
      final json = {
        'plan': {
          'id': 'growth',
          'name': 'Growth',
          'description': 'Advanced operations',
          'features': {'advancedAnalytics': true, 'exportData': true},
        },
        'subscription': {
          'status': 'active',
          'startDate': '2026-10-01T00:00:00.000Z',
          'endDate': '2026-11-01T00:00:00.000Z',
          'isExpired': false,
          'inGracePeriod': false,
        },
        'usage': {
          'activeMenuItems': {'current': 24, 'max': 50},
          'staffAccounts': {'current': 3, 'max': 5},
        },
      };

      final sub = SubscriptionInfo.fromJson(json);
      expect(sub.planId, 'growth');
      expect(sub.planName, 'Growth');
      expect(sub.status, 'active');
      expect(sub.activeItemsCurrent, 24);
      expect(sub.activeItemsMax, 50);
      expect(sub.staffCurrent, 3);
      expect(sub.staffMax, 5);
      expect(sub.allowAdvancedAnalytics, isTrue);
      expect(sub.allowExport, isTrue);
      expect(sub.isExpired, isFalse);
    });
  });

  group('Phase 5 — RestaurantProvider RBAC & Operations', () {
    test('Correctly exposes role getters', () {
      final provider = RestaurantProvider();

      provider.setRoleForTest('owner');
      expect(provider.isOwner, isTrue);
      expect(provider.isManager, isTrue);
      expect(provider.isKitchen, isFalse);

      provider.setRoleForTest('kitchen');
      expect(provider.isKitchen, isTrue);
      expect(provider.isOwner, isFalse);
      expect(provider.isManager, isFalse);

      provider.setRoleForTest('cashier');
      expect(provider.isCashier, isTrue);
      expect(provider.isKitchen, isFalse);

      provider.setRoleForTest('viewer');
      expect(provider.isViewer, isTrue);
    });

    test('addStaff sends request and handles response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/restaurant/admin/staff')) {
          final body = jsonDecode(request.body);
          expect(body['email'], 'newstaff@test.com');
          expect(body['role'], 'manager');
          return http.Response(
            jsonEncode({
              'message': 'Staff member added successfully',
              'staffMember': {
                '_id': 'new_1',
                'email': 'newstaff@test.com',
                'role': 'manager',
                'name': 'New Staff',
              },
            }),
            201,
          );
        }
        return http.Response('{"staff": []}', 200);
      });

      final provider = RestaurantProvider();
      final success = await provider.addStaff(
        'newstaff@test.com',
        name: 'New Staff',
        role: 'manager',
        client: mockClient,
        overrideToken: 'mock_token',
      );
      expect(success, isTrue);
    });
  });

  group('Phase 5 — Order Idempotency Key', () {
    test('OrderProvider generates and attaches idempotencyKey', () async {
      String? capturedIdempotencyHeader;
      String? capturedIdempotencyBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/order/add')) {
          capturedIdempotencyHeader = request.headers['X-Idempotency-Key'];
          final body = jsonDecode(request.body);
          capturedIdempotencyBody = body['idempotencyKey'];

          return http.Response(
            jsonEncode({
              'message': 'Order Placed !!',
              'order': {
                '_id': '65e3a1b2c3d4e5f6a7b8c9d0',
                'totalAmount': 100,
                'status': 'Processing',
                'paymentStatus': 'Pending',
              },
            }),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = OrderProvider();
      provider.addToCart(
        Item(itemId: '1', itemName: 'Burger', itemPrice: 100, category: 'Fast Food', isAvailable: true),
      );

      final order = await provider.placeOrder(
        paymentMethod: 'COD',
        client: mockClient,
        overrideToken: 'mock_token',
      );

      expect(order, isNotNull);
      expect(capturedIdempotencyHeader, isNotNull);
      expect(capturedIdempotencyBody, isNotNull);
      expect(capturedIdempotencyHeader, capturedIdempotencyBody);
      expect(capturedIdempotencyHeader!.startsWith('order_'), isTrue);
    });
  });

  group('Phase 5 — AdminPage Role-Based UI Gating', () {
    testWidgets('Kitchen role displays ONLY Live Orders and restricts Settings/Menu/Analytics',
        (tester) async {
      final restaurantProvider = RestaurantProvider();
      restaurantProvider.setRoleForTest('kitchen');

      final orderProvider = AdminOrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: restaurantProvider),
            ChangeNotifierProvider.value(value: orderProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: AdminPage(),
          ),
        ),
      );

      await tester.pump();

      // Check role pill
      expect(find.text('KITCHEN'), findsOneWidget);

      // Bottom bar must not show Settings, Analytics, or Menu List for kitchen
      expect(find.text('Live Orders'), findsNothing); // 1 screen => bottom nav is hidden
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Analytics'), findsNothing);
      expect(find.text('Menu List'), findsNothing);

      orderProvider.stopPolling();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Owner role displays all 5 navigation tabs including Settings',
        (tester) async {
      final restaurantProvider = RestaurantProvider();
      restaurantProvider.setRoleForTest('owner');

      final orderProvider = AdminOrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: restaurantProvider),
            ChangeNotifierProvider.value(value: orderProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: AdminPage(),
          ),
        ),
      );

      await tester.pump();

      // Check role pill
      expect(find.text('OWNER'), findsOneWidget);

      // Bottom bar shows all 5 items
      expect(find.text('Live Orders'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Menu List'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      orderProvider.stopPolling();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Phase 5 — AdminSettingsPage Subscription & Staff UI', () {
    testWidgets('Renders Subscription Card and Staff Management Card', (tester) async {
      final restaurantProvider = RestaurantProvider();
      restaurantProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo Central',
          isOpen: true,
          availabilityStatus: 'OPEN',
        ),
      );
      restaurantProvider.setSubscriptionForTest(
        SubscriptionInfo(
          planId: 'growth',
          planName: 'Growth',
          planDescription: 'Operations plan',
          status: 'active',
          activeItemsCurrent: 15,
          activeItemsMax: 50,
          staffCurrent: 3,
          staffMax: 5,
        ),
      );
      restaurantProvider.setStaffForTest([
        StaffMember(
          id: 's1',
          email: 'owner@serveo.com',
          name: 'Main Owner',
          role: 'owner',
        ),
        StaffMember(
          id: 's2',
          email: 'cook@serveo.com',
          name: 'Head Chef',
          role: 'kitchen',
        ),
      ]);

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: restaurantProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: AdminSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Subscription card
      expect(find.text('Commercial Subscription'), findsOneWidget);
      expect(find.text('Growth • ACTIVE'), findsOneWidget);
      expect(find.text('15 / 50 items'), findsOneWidget);
      expect(find.text('3 / 5 accounts'), findsOneWidget);

      // Check Staff card
      expect(find.text('Staff Accounts & Roles (RBAC)'), findsOneWidget);
      expect(find.text('Main Owner'), findsOneWidget);
      expect(find.text('Head Chef'), findsOneWidget);
      expect(find.byKey(const Key('admin_add_staff_btn')), findsOneWidget);
    });
  });
}

