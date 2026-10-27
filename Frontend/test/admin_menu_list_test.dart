import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_widgets/admin_menu_list_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleAvailableItem = Item(
    itemId: '6ad8cc2026351aad0e94af8d',
    itemName: 'Veggie Crunch Burger',
    itemPrice: 89,
    category: 'Burgers',
    isAvailable: true,
  );

  final sampleSoldOutItem = Item(
    itemId: '6ad8cc2026351aad0e94af8e',
    itemName: 'Paneer Tikka Pizza',
    itemPrice: 199,
    category: 'Pizza',
    isAvailable: false,
  );

  group('Admin Menu List UI & Layout Tests', () {
    testWidgets('Renders Menu List heading and Add Item FAB', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(
              initialItems: [sampleAvailableItem],
            ),
          ),
        ),
      );

      expect(find.text('Menu List'), findsOneWidget);
      expect(find.byKey(const Key('admin_add_item_fab')), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.text('Add Item'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Burgers'), findsWidgets);
      expect(find.text('Pizza'), findsOneWidget);
    });

    test('Item model correctly deserializes from MongoDB JSON representation', () {
      final json = {
        '_id': 'item_001',
        'itemName': 'Paneer Tikka Sandwich',
        'itemPrice': 119,
        'category': 'Sandwiches',
        'description': 'Grilled cottage cheese with spices',
        'isAvailable': true,
        'imageUrl': '/item/image/abc123',
        'isVeg': true,
        'dietary': 'Veg'
      };

      final item = Item.fromJson(json);
      expect(item.itemId, 'item_001');
      expect(item.itemName, 'Paneer Tikka Sandwich');
      expect(item.itemPrice, 119);
      expect(item.category, 'Sandwiches');
      expect(item.isAvailable, isTrue);
      expect(item.imageUrl, '/item/image/abc123');
    });

    test('Item model handles sold out item correctly', () {
      final json = {
        '_id': 'item_002',
        'itemName': 'Cold Coffee',
        'itemPrice': 79,
        'category': 'Beverages',
        'isAvailable': false,
      };

      final item = Item.fromJson(json);
      expect(item.itemId, 'item_002');
      expect(item.isAvailable, isFalse);
    });

    test('Item copyWith works cleanly without mutating original', () {
      final original = Item(
        itemId: 'id_1',
        itemName: 'Burger',
        itemPrice: 50,
        category: 'Burgers',
        isAvailable: true,
      );
      final toggled = original.copyWith(isAvailable: false);
      expect(original.isAvailable, isTrue);
      expect(toggled.isAvailable, isFalse);
      expect(toggled.itemName, 'Burger');
      expect(toggled.itemPrice, 50);
    });
  });

  group('Bug 1 — Food Availability Toggle Tests', () {
    testWidgets('Toggles availability from Available -> Sold Out after server confirms', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? capturedMethod;
      String? capturedUrl;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedUrl = request.url.toString();
        capturedBody = jsonDecode(request.body);

        return http.Response(
          jsonEncode({
            'message': 'Item updated successfully',
            'item': {
              '_id': '6ad8cc2026351aad0e94af8d',
              'itemName': 'Veggie Crunch Burger',
              'isAvailable': false,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(
              mockHttpClient: mockClient,
              initialItems: [sampleAvailableItem],
            ),
          ),
        ),
      );

      expect(find.text('Available'), findsOneWidget);

      final switchFinder = find.byKey(const Key('item_switch_6ad8cc2026351aad0e94af8d'));
      expect(switchFinder, findsOneWidget);

      // Tap switch to toggle available -> unavailable
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify request method and payload
      expect(capturedMethod, 'PUT');
      expect(capturedUrl, contains('/item/6ad8cc2026351aad0e94af8d'));
      expect(capturedBody?['isAvailable'], isFalse);

      // Verify UI updated after confirmed server response
      expect(find.text('Sold Out'), findsOneWidget);
      expect(find.text("'Veggie Crunch Burger' is now Sold Out"), findsOneWidget);
    });

    testWidgets('Toggles availability from Sold Out -> Available after server confirms', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Item updated successfully',
            'item': {
              '_id': '6ad8cc2026351aad0e94af8e',
              'itemName': 'Paneer Tikka Pizza',
              'isAvailable': true,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(
              mockHttpClient: mockClient,
              initialItems: [sampleSoldOutItem],
            ),
          ),
        ),
      );

      expect(find.text('Sold Out'), findsOneWidget);

      final switchFinder = find.byKey(const Key('item_switch_6ad8cc2026351aad0e94af8e'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Available'), findsOneWidget);
      expect(find.text("'Paneer Tikka Pizza' is now Available"), findsOneWidget);
    });

    testWidgets('Preserves toggle state and shows error when backend returns 404', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Item not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(
              mockHttpClient: mockClient,
              initialItems: [sampleAvailableItem],
            ),
          ),
        ),
      );

      // Initially Available
      expect(find.text('Available'), findsOneWidget);

      final switchFinder = find.byKey(const Key('item_switch_6ad8cc2026351aad0e94af8d'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // UI must remain Available because update failed
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Sold Out'), findsNothing);
      expect(find.text('Item not found'), findsOneWidget);
    });

    testWidgets('Preserves toggle state and displays safe message when server returns HTML error page', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          '<!DOCTYPE html><html><body><h1>502 Bad Gateway</h1></body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(
              mockHttpClient: mockClient,
              initialItems: [sampleAvailableItem],
            ),
          ),
        ),
      );

      final switchFinder = find.byKey(const Key('item_switch_6ad8cc2026351aad0e94af8d'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // UI remains Available
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Sold Out'), findsNothing);
      expect(find.textContaining('Server error (502)'), findsOneWidget);
    });

    testWidgets('Rejects toggle when item ID is empty and shows warning', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool requestMade = false;
      final mockClient = MockClient((request) async {
        requestMade = true;
        return http.Response('{}', 200);
      });

      final invalidItem = Item(
        itemId: '',
        itemName: 'Ghost Item',
        itemPrice: 50,
        category: 'Snacks',
        isAvailable: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(
              mockHttpClient: mockClient,
              initialItems: [invalidItem],
            ),
          ),
        ),
      );

      final switchFinder = find.byKey(const Key('item_switch_'));
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(requestMade, isFalse, reason: 'Must not send HTTP request when ID is empty');
      expect(find.text('Cannot update availability: Item ID is missing.'), findsOneWidget);
    });
  });
}
