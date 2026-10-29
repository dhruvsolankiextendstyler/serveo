import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_widgets/admin_settings_page.dart';
import 'package:frontend/pages/cart_page.dart';
import 'package:frontend/pages/dashboard_page.dart';
import 'package:frontend/utils/menu_provider.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/restaurant_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:frontend/widgets/breakbite_appbar.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: RestaurantConfig Model & Parsing Tests', () {
    test('RestaurantConfig parses full backend payload accurately', () {
      final json = {
        'id': '65dfa0000000000000000001',
        'name': 'Campus Central Bistro',
        'slug': 'campus-bistro',
        'description': 'Delicious meals made fresh daily',
        'currency': 'INR',
        'currencySymbol': '₹',
        'timezone': 'Asia/Kolkata',
        'operatingDays': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        'openingTime': '08:30',
        'closingTime': '21:30',
        'defaultEstimatedPrepTime': 25,
        'isOrderAcceptancePaused': false,
        'pauseReason': '',
        'address': {
          'street': 'Food Court St 1',
          'city': 'Bengaluru',
          'state': 'Karnataka',
          'postalCode': '560001',
        },
        'contact': {
          'phone': '+91 9123456789',
          'email': 'bistro@college.edu',
        },
        'displayPreferences': {
          'announcement': 'Special 20% discount on Thali!',
          'showPrepTime': true,
          'showDietaryBadges': true,
        },
        'availability': {
          'isOpen': true,
          'status': 'OPEN',
          'reason': 'Restaurant is open for orders.',
          'operatingHours': '08:30 - 21:30',
        }
      };

      final config = RestaurantConfig.fromJson(json);

      expect(config.id, '65dfa0000000000000000001');
      expect(config.name, 'Campus Central Bistro');
      expect(config.slug, 'campus-bistro');
      expect(config.openingTime, '08:30');
      expect(config.closingTime, '21:30');
      expect(config.operatingDays.length, 5);
      expect(config.defaultEstimatedPrepTime, 25);
      expect(config.canOrder, isTrue);
      expect(config.isPaused, isFalse);
      expect(config.isClosed, isFalse);
      expect(config.announcement, 'Special 20% discount on Thali!');
    });

    test('RestaurantConfig applies sensible defaults for missing or empty JSON', () {
      final config = RestaurantConfig.fromJson({});

      expect(config.name, 'Serveo');
      expect(config.currency, 'INR');
      expect(config.currencySymbol, '₹');
      expect(config.openingTime, '09:00');
      expect(config.closingTime, '22:00');
      expect(config.operatingDays.length, 7);
      expect(config.canOrder, isTrue);
      expect(config.isPaused, isFalse);
    });

    test('RestaurantConfig accurately identifies PAUSED status', () {
      final config = RestaurantConfig.fromJson({
        'isOrderAcceptancePaused': true,
        'pauseReason': 'Kitchen under maintenance',
        'availability': {
          'isOpen': false,
          'status': 'PAUSED',
          'reason': 'Kitchen under maintenance',
        }
      });

      expect(config.isPaused, isTrue);
      expect(config.canOrder, isFalse);
      expect(config.isClosed, isFalse);
      expect(config.availabilityReason, 'Kitchen under maintenance');
    });

    test('RestaurantConfig accurately identifies CLOSED status', () {
      final config = RestaurantConfig.fromJson({
        'isOrderAcceptancePaused': false,
        'availability': {
          'isOpen': false,
          'status': 'CLOSED',
          'reason': 'Restaurant is closed on Sundays.',
          'operatingHours': '09:00 - 22:00',
        }
      });

      expect(config.isClosed, isTrue);
      expect(config.canOrder, isFalse);
      expect(config.isPaused, isFalse);
      expect(config.availabilityReason, contains('closed'));
    });
  });

  group('Phase 4: RestaurantProvider Operations Tests', () {
    test('fetchPublicInfo updates provider state cleanly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/restaurant/public/info'));
        return http.Response(
          jsonEncode({
            'restaurant': {
              'name': 'Gourmet Express',
              'slug': 'gourmet-express',
              'currency': 'INR',
              'availability': {'isOpen': true, 'status': 'OPEN'}
            }
          }),
          200,
        );
      });

      final provider = RestaurantProvider();
      await provider.fetchPublicInfo(client: mockClient);

      expect(provider.config.name, 'Gourmet Express');
      expect(provider.config.canOrder, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('updateSettings updates restaurant configuration', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body);
          expect(body['name'], 'New Bistro Name');
          return http.Response(
            jsonEncode({
              'message': 'Settings saved',
              'restaurant': {
                'name': 'New Bistro Name',
                'openingTime': '10:00',
                'closingTime': '23:00',
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = RestaurantProvider();
      final success = await provider.updateSettings(
        {'name': 'New Bistro Name'},
        client: mockClient,
        overrideToken: 'mock_token',
      );

      expect(success, isTrue);
      expect(provider.config.name, 'New Bistro Name');
    });

    test('togglePauseOrders updates pause state', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body);
          expect(body['isOrderAcceptancePaused'], isTrue);
          expect(body['pauseReason'], 'Overloaded');
          return http.Response(
            jsonEncode({'message': 'Paused', 'isOrderAcceptancePaused': true}),
            200,
          );
        } else if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'restaurant': {
                'name': 'Serveo',
                'isOrderAcceptancePaused': true,
                'pauseReason': 'Overloaded',
                'availability': {'isOpen': false, 'status': 'PAUSED', 'reason': 'Overloaded'}
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = RestaurantProvider();
      final success = await provider.togglePauseOrders(
        true,
        reason: 'Overloaded',
        client: mockClient,
        overrideToken: 'mock_token',
      );

      expect(success, isTrue);
      expect(provider.config.isPaused, isTrue);
    });
  });

  group('Phase 4: AdminSettingsPage Widget Tests', () {
    testWidgets('Renders all business configuration cards and controls', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'The Central Grill',
          description: 'Finest grilled treats on campus',
          openingTime: '10:00',
          closingTime: '23:00',
          operatingDays: ['Monday', 'Tuesday', 'Wednesday'],
          defaultEstimatedPrepTime: 25,
          contactPhone: '+91 9876543210',
          contactEmail: 'grill@serveo.test',
          announcement: 'Welcome students!',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
            ],
            child: const AdminSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card headings
      expect(find.text('Restaurant Identity'), findsOneWidget);
      expect(find.text('Operating Hours & Schedule'), findsOneWidget);
      expect(find.text('Address & Contact Information'), findsOneWidget);
      expect(find.text('Digital Restaurant QR Menu'), findsOneWidget);
      expect(find.byKey(const Key('admin_save_settings_btn')), findsOneWidget);
      expect(find.byKey(const Key('admin_pause_orders_switch')), findsOneWidget);
    });
  });

  group('Phase 4: Customer Dashboard & Availability Alert Tests', () {
    testWidgets('Dashboard displays custom restaurant name and announcement', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Bistro Royale',
          description: 'Royal meals for student champions',
          announcement: 'Flash Sale: 20% off all beverages!',
        ),
      );

      final menuProvider = MenuProvider();
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<MenuProvider>.value(value: menuProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const DashboardPage(uname: 'Rohan'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bistro Royale'), findsWidgets);
      expect(find.text('Flash Sale: 20% off all beverages!'), findsOneWidget);
      // No closed banner when OPEN
      expect(find.byKey(const Key('dashboard_restaurant_status_banner')), findsNothing);
    });

    testWidgets('Dashboard renders closed status banner when restaurant is closed', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo Bistro',
          isOpen: false,
          availabilityStatus: 'CLOSED',
          availabilityReason: 'Restaurant is currently closed. Today\'s hours: 09:00 - 22:00',
          openingTime: '09:00',
          closingTime: '22:00',
        ),
      );

      final menuProvider = MenuProvider();
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<MenuProvider>.value(value: menuProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const DashboardPage(uname: 'Student'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_restaurant_status_banner')), findsOneWidget);
      expect(find.text('Currently Closed for Orders'), findsOneWidget);
    });

    testWidgets('Dashboard renders paused status banner with custom pause reason', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo Bistro',
          isOrderAcceptancePaused: true,
          isOpen: false,
          availabilityStatus: 'PAUSED',
          availabilityReason: 'Kitchen maintenance until 3 PM',
        ),
      );

      final menuProvider = MenuProvider();
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<MenuProvider>.value(value: menuProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const DashboardPage(uname: 'Student'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_restaurant_status_banner')), findsOneWidget);
      expect(find.text('Ordering Paused'), findsOneWidget);
      expect(find.text('Kitchen maintenance until 3 PM'), findsOneWidget);
    });
  });

  group('Phase 4: Customer Cart Checkout Prevention Tests', () {
    testWidgets('CartPage blocks checkout when restaurant is closed and preserves tray', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo',
          isOpen: false,
          availabilityStatus: 'CLOSED',
          availabilityReason: 'Restaurant closed for the night',
        ),
      );

      final orderProvider = OrderProvider();
      orderProvider.addToCart(
        Item(itemId: 'it_1', itemName: 'Veggie Burger', itemPrice: 120, category: 'Burgers'),
      );

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const CartPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Closed banner is rendered on cart
      expect(find.byKey(const Key('cart_restaurant_closed_banner')), findsOneWidget);
      expect(find.text('Ordering Currently Unavailable'), findsOneWidget);

      // Verify item remains preserved in tray
      expect(find.text('Veggie Burger'), findsOneWidget);
      expect(orderProvider.orderItems.length, 1);
    });

    testWidgets('CartPage enables Proceed to Pay when restaurant is open', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo',
          isOpen: true,
          availabilityStatus: 'OPEN',
        ),
      );

      final orderProvider = OrderProvider();
      orderProvider.addToCart(
        Item(itemId: 'it_1', itemName: 'Cold Coffee', itemPrice: 80, category: 'Beverages'),
      );

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const CartPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cart_restaurant_closed_banner')), findsNothing);
      expect(find.text('Proceed to Pay • ₹80'), findsOneWidget);
    });
  });

  group('Phase 4: ServeoAppBar Branding Tests', () {
    testWidgets('ServeoAppBar displays configured restaurant name', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(name: 'Campus Diner'),
      );

      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const Scaffold(
              appBar: ServeoAppBar(),
              body: Center(child: Text('Content')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Campus Diner'), findsOneWidget);
    });
  });
}

