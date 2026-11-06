import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_widgets/admin_settings_page.dart';
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

  final sampleItems = [
    Item(
      itemId: "item_burger_1",
      itemName: "Classic Cheese Burger",
      itemPrice: 129,
      category: "Burgers",
      description: "Juicy burger with cheddar cheese and fresh lettuce",
      isAvailable: true,
      isVeg: false,
      dietary: "Non-Veg",
    ),
    Item(
      itemId: "item_pizza_1",
      itemName: "Paneer Pizza",
      itemPrice: 199,
      category: "Pizza",
      description: "Crispy crust topped with spiced paneer cubes and herbs",
      isAvailable: true,
      isVeg: true,
      dietary: "Veg",
    ),
    Item(
      itemId: "item_brownie_1",
      itemName: "Chocolate Brownie",
      itemPrice: 89,
      category: "Desserts",
      description: "Warm fudgy chocolate brownie with chocolate drizzle",
      isAvailable: true,
      isVeg: true,
      dietary: "Veg",
    ),
    Item(
      itemId: "item_bev_1",
      itemName: "Cold Coffee",
      itemPrice: 69,
      category: "Beverages",
      description: "Iced blend of rich espresso and creamy milk",
      isAvailable: false, // Sold Out
      isVeg: true,
      dietary: "Veg",
    ),
  ];

  group('PART 1 — Customer Mobile Home / Menu Redesign Tests', () {
    testWidgets('1 & 3: Shows single branding in AppBar; removes duplicate branding and welcome text on mobile', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo',
          description: 'Fresh meals prepared to order',
          isOpen: true,
          availabilityStatus: 'OPEN',
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

      // Top AppBar contains Serveo branding
      expect(find.byType(ServeoAppBar), findsOneWidget);
      expect(find.descendant(of: find.byType(ServeoAppBar), matching: find.text('Serveo')), findsOneWidget);

      // Welcome message is removed on mobile
      expect(find.textContaining('Welcome, Rohan!'), findsNothing);
      expect(find.textContaining('Welcome to Serveo! Fresh meals prepared to order.'), findsNothing);
    });

    testWidgets('2: Search bar is collapsed initially and smoothly expands on tap', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(RestaurantConfig(isOpen: true, availabilityStatus: 'OPEN'));

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
            child: const DashboardPage(uname: 'TestUser'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially, search text field is not shown in normal body flow
      expect(find.byKey(const Key('appbar_search_textfield')), findsNothing);
      expect(find.byKey(const Key('appbar_search_toggle_btn')), findsOneWidget);

      // Tap search icon button in AppBar
      await tester.tap(find.byKey(const Key('appbar_search_toggle_btn')));
      await tester.pumpAndSettle();

      // Search field smoothly appears
      expect(find.byKey(const Key('appbar_search_textfield')), findsOneWidget);
      expect(find.byKey(const Key('appbar_search_back_btn')), findsOneWidget);

      // Type in search query
      await tester.enterText(find.byKey(const Key('appbar_search_textfield')), 'Burger');
      await tester.pumpAndSettle();

      // Tap back button to close search
      await tester.tap(find.byKey(const Key('appbar_search_back_btn')));
      await tester.pumpAndSettle();

      // Collapses back to compact state
      expect(find.byKey(const Key('appbar_search_textfield')), findsNothing);
      expect(find.byKey(const Key('appbar_search_toggle_btn')), findsOneWidget);
    });

    testWidgets('4: Closed / Paused status floats at bottom of mobile screen and does not block items', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo',
          isOpen: false,
          availabilityStatus: 'CLOSED',
          availabilityReason: 'Opens at 9:00 AM',
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
            child: const DashboardPage(uname: 'Customer'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Floating status banner is rendered with appropriate key and text
      final bannerFinder = find.byKey(const Key('dashboard_restaurant_status_banner'));
      expect(bannerFinder, findsOneWidget);
      expect(find.text('Currently Closed for Orders'), findsOneWidget);
      expect(find.text('Opens at 9:00 AM'), findsOneWidget);

      // Positioned near the bottom of viewport
      final bannerTop = tester.getTopLeft(bannerFinder).dy;
      expect(bannerTop, greaterThan(650.0));
    });

    testWidgets('5: Popular Items section acts as compact quick-access horizontal carousel with direct ADD', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(RestaurantConfig(isOpen: true, availabilityStatus: 'OPEN'));

      final menuProvider = MenuProvider();
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      // Seed sample items into menu
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': sampleItems.map((it) => {
              'itemId': it.itemId,
              'itemName': it.itemName,
              'itemPrice': it.itemPrice,
              'category': it.category,
              'description': it.description,
              'isAvailable': it.isAvailable,
              'isVeg': it.isVeg,
              'dietary': it.dietary,
            }).toList()
          }),
          200,
        );
      });
      await menuProvider.fetchMenu(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<MenuProvider>.value(value: menuProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const DashboardPage(uname: 'Customer'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Popular items section is visible
      expect(find.text('POPULAR ITEMS'), findsOneWidget);

      // Direct "+ ADD" button works and adds item to cart
      final addButtons = find.text('+ ADD');
      expect(addButtons, findsWidgets);

      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(orderProvider.orderItems.length, 1);
      expect(find.text('1 ITEM IN TRAY'), findsOneWidget);
    });

    testWidgets('7 & 8: No RenderFlex overflow on narrow 320px mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(RestaurantConfig(isOpen: true, availabilityStatus: 'OPEN'));

      final menuProvider = MenuProvider();
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
              ChangeNotifierProvider<MenuProvider>.value(value: menuProvider),
              ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ],
            child: const DashboardPage(uname: 'NarrowDevice'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zero exceptions and clean render on 320px narrow width
      expect(tester.takeException(), isNull);
    });
  });

  group('PART 2 — Operating Hours & Admin Settings Persistence Tests', () {
    testWidgets('Operating hours & schedule card supports clock-style time selection & daily schedule', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setConfigForTest(
        RestaurantConfig(
          name: 'Serveo Bistro',
          openingTime: '09:00',
          closingTime: '22:00',
          operatingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
          schedule: [
            const OperatingDaySchedule(day: 'Monday', isOpen: true, openTime: '09:00', closeTime: '22:00'),
            const OperatingDaySchedule(day: 'Tuesday', isOpen: true, openTime: '09:00', closeTime: '22:00'),
            const OperatingDaySchedule(day: 'Wednesday', isOpen: true, openTime: '09:00', closeTime: '22:00'),
            const OperatingDaySchedule(day: 'Thursday', isOpen: true, openTime: '09:00', closeTime: '22:00'),
            const OperatingDaySchedule(day: 'Friday', isOpen: true, openTime: '09:00', closeTime: '22:00'),
            const OperatingDaySchedule(day: 'Saturday', isOpen: true, openTime: '10:00', closeTime: '23:00'),
            const OperatingDaySchedule(day: 'Sunday', isOpen: false, openTime: '09:00', closeTime: '22:00'),
          ],
        ),
      );

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
            ],
            child: const AdminSettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Schedule section is rendered
      expect(find.text('Operating Hours & Schedule'), findsOneWidget);
      expect(find.text('Daily Operating Hours (Clock-Style)'), findsOneWidget);

      // Verify days in daily schedule
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Saturday'), findsOneWidget);
      expect(find.text('Sunday'), findsOneWidget);

      // Tapping time opens time picker
      final mondayOpenTime = find.text('09:00 AM');
      expect(mondayOpenTime, findsWidgets);

      await tester.tap(mondayOpenTime.first);
      await tester.pumpAndSettle();

      // Clock-style Material time picker is visible
      expect(find.byType(TimePickerTheme), findsWidgets);
      expect(find.text('OK'), findsOneWidget);

      // Close picker
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    test('RestaurantConfig preserves and serializes per-day schedule cleanly', () {
      final json = {
        'id': 'rest_123',
        'name': 'Serveo Cafe',
        'openingTime': '08:00',
        'closingTime': '20:00',
        'schedule': [
          {'day': 'Monday', 'isOpen': true, 'openTime': '08:00', 'closeTime': '20:00'},
          {'day': 'Sunday', 'isOpen': false, 'openTime': '09:00', 'closeTime': '18:00'},
        ],
        'availability': {
          'isOpen': true,
          'status': 'OPEN',
          'hoursFormatted': '08:00 - 20:00',
        }
      };

      final cfg = RestaurantConfig.fromJson(json);
      expect(cfg.schedule.length, 2);
      expect(cfg.schedule[0].day, 'Monday');
      expect(cfg.schedule[0].isOpen, isTrue);
      expect(cfg.schedule[0].openTime, '08:00');
      expect(cfg.schedule[1].day, 'Sunday');
      expect(cfg.schedule[1].isOpen, isFalse);

      final serialized = cfg.toJson();
      expect(serialized['schedule'], isA<List>());
      expect((serialized['schedule'] as List).length, 2);
    });
  });
}

