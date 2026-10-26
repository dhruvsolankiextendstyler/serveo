import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_widgets/admin_menu_list_page.dart';
import 'package:frontend/utils/order_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Menu List UI & Interaction Tests', () {
    testWidgets('Renders Menu List heading and Add Item FAB', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminMenuListPage(),
          ),
        ),
      );

      // Verify page heading
      expect(find.text('Menu List'), findsOneWidget);

      // Verify Add Item FAB is rendered with add icon and key
      expect(find.byKey(const Key('admin_add_item_fab')), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
      expect(find.text('Add Item'), findsOneWidget);

      // Verify category filter chips are present
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Burgers'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Sandwiches'), findsOneWidget);
      expect(find.text('Beverages'), findsOneWidget);
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
  });
}
