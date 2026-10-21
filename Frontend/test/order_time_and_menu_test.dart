import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/widgets/breakbite_food_card.dart';
import 'package:flutter/material.dart';

void main() {
  group('AdminOrder Timestamp & Timezone Tests', () {
    test('Converts UTC timestamp to Asia/Kolkata (UTC + 5:30)', () {
      // 14:12 UTC = 19:42 Asia/Kolkata (7:42 PM)
      final orderJson = {
        '_id': 'ord1234567890',
        'userId': 'usr1',
        'totalAmount': 250,
        'status': 'Processing',
        'createdAt': '2026-10-21T14:12:00.000Z',
        'orderItems': [],
      };

      final order = AdminOrder.fromJson(orderJson);
      expect(order.createdAt, isNotNull);
      // In Asia/Kolkata, 14:12 UTC is 19:42 -> 7:42 PM
      expect(order.formattedPlacementTime.contains('7:42 PM'), isTrue);
    });

    test('Handles missing, empty or null timestamps gracefully', () {
      final orderWithoutTimestamp = AdminOrder.fromJson({
        '_id': 'ord9999',
        'userId': 'usr2',
        'totalAmount': 100,
        'status': 'Processing',
        'orderItems': [],
      });

      expect(orderWithoutTimestamp.createdAt, isNull);
      expect(() => orderWithoutTimestamp.formattedPlacementTime, returnsNormally);
    });

    test('Handles invalid timestamp strings without crashing', () {
      final orderInvalid = AdminOrder.fromJson({
        '_id': 'ord8888',
        'userId': 'usr3',
        'totalAmount': 50,
        'status': 'Completed',
        'createdAt': 'invalid-date-format',
        'orderItems': [],
      });

      expect(orderInvalid.createdAt, isNull);
      expect(() => orderInvalid.formattedPlacementTime, returnsNormally);
    });
  });

  group('Category Icon Helpers', () {
    test('Maps categories to appropriate icons', () {
      expect(getCategoryIcon('Burgers'), equals(Icons.lunch_dining));
      expect(getCategoryIcon('Pizza'), equals(Icons.local_pizza));
      expect(getCategoryIcon('Sandwiches'), equals(Icons.bakery_dining));
      expect(getCategoryIcon('Snacks'), equals(Icons.fastfood));
      expect(getCategoryIcon('Beverages'), equals(Icons.local_cafe));
      expect(getCategoryIcon('Desserts'), equals(Icons.cake));
      expect(getCategoryIcon('All'), equals(Icons.restaurant_menu));
      expect(getCategoryIcon('Unknown'), equals(Icons.restaurant));
    });
  });
}
