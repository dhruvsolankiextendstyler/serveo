import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/admin_widgets/admin_page.dart';
import 'package:frontend/admin_widgets/admin_marketing_page.dart';
import 'package:frontend/pages/customer_referral_page.dart';
import 'package:frontend/utils/menu_provider.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/restaurant_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:frontend/widgets/breakbite_bill_details_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6 — Subscription & Plan Entitlements', () {
    test('Starter plan parses allowMarketingAndLoyalty as false', () {
      final json = {
        'plan': {
          'id': 'starter',
          'name': 'Starter',
          'features': {
            'marketingAndLoyalty': false,
            'customerRetentionAnalytics': false,
          },
        },
        'subscription': {'status': 'active'},
        'usage': {},
      };

      final sub = SubscriptionInfo.fromJson(json);
      expect(sub.planId, 'starter');
      expect(sub.allowMarketingAndLoyalty, isFalse);
      expect(sub.allowCustomerRetentionAnalytics, isFalse);
    });

    test('Growth and Premium plans parse allowMarketingAndLoyalty as true', () {
      final json = {
        'plan': {
          'id': 'growth',
          'name': 'Growth',
          'features': {
            'marketingAndLoyalty': true,
            'customerRetentionAnalytics': true,
          },
        },
        'subscription': {'status': 'active'},
        'usage': {},
      };

      final sub = SubscriptionInfo.fromJson(json);
      expect(sub.planId, 'growth');
      expect(sub.allowMarketingAndLoyalty, isTrue);
      expect(sub.allowCustomerRetentionAnalytics, isTrue);
    });
  });

  group('Phase 6 — OrderProvider Coupon & Loyalty Calculation', () {
    test('Calculates final payable total accurately with coupon and loyalty discounts', () {
      final provider = OrderProvider();

      // Add mock item to tray
      provider.addItem(
        MenuItem(
          id: 'item_1',
          name: 'Paneer Butter Masala',
          price: 250,
          category: 'Curry',
          available: true,
        ),
      );
      provider.addItem(
        MenuItem(
          id: 'item_2',
          name: 'Butter Naan',
          price: 50,
          category: 'Breads',
          available: true,
        ),
      );

      // Subtotal should be 300
      expect(provider.getTotal(), 300);
      expect(provider.getFinalPayableTotal(), 300);

      // Apply coupon (₹50 discount)
      provider.applyCoupon('WELCOME50', 50.0);
      expect(provider.appliedCouponCode, 'WELCOME50');
      expect(provider.couponDiscount, 50.0);
      expect(provider.getFinalPayableTotal(), 250);

      // Apply loyalty reward (₹30 discount)
      provider.selectLoyaltyReward('reward_1', 30.0);
      expect(provider.selectedRewardId, 'reward_1');
      expect(provider.loyaltyDiscount, 30.0);
      expect(provider.getFinalPayableTotal(), 220);

      // Remove coupon
      provider.removeCoupon();
      expect(provider.appliedCouponCode, isNull);
      expect(provider.couponDiscount, 0.0);
      expect(provider.getFinalPayableTotal(), 270);

      // Deselect loyalty reward
      provider.deselectLoyaltyReward();
      expect(provider.selectedRewardId, isNull);
      expect(provider.loyaltyDiscount, 0.0);
      expect(provider.getFinalPayableTotal(), 300);
    });

    test('Prevents negative payable total when discount exceeds subtotal', () {
      final provider = OrderProvider();
      provider.addItem(
        MenuItem(
          id: 'item_tea',
          name: 'Masala Chai',
          price: 20,
          category: 'Beverages',
          available: true,
        ),
      );

      expect(provider.getTotal(), 20);

      // Apply a large discount
      provider.applyCoupon('SUPER100', 100.0);
      expect(provider.getFinalPayableTotal(), 0);
    });
  });

  group('Phase 6 — BillDetailsCard Widget Test', () {
    testWidgets('Renders subtotal, coupon discount, and net grand total', (tester) async {
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      orderProvider.addItem(
        MenuItem(
          id: 'item_1',
          name: 'Veg Biryani',
          price: 200,
          category: 'Rice',
          available: true,
        ),
      );
      orderProvider.applyCoupon('FEAST20', 40.0);
      orderProvider.selectLoyaltyReward('rew_loyalty', 20.0);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BillDetailsCard(),
            ),
          ),
        ),
      );

      // Verify subtotal, discounts, and net grand total
      expect(find.text("Item Total"), findsOneWidget);
      expect(find.text("₹200"), findsOneWidget);
      expect(find.text("Coupon (FEAST20)"), findsOneWidget);
      expect(find.text("-₹40"), findsOneWidget);
      expect(find.text("Loyalty Reward"), findsOneWidget);
      expect(find.text("-₹20"), findsOneWidget);
      expect(find.text("Grand Total"), findsOneWidget);
      expect(find.text("₹140"), findsOneWidget);
    });
  });

  group('Phase 6 — Admin Page Navigation & Role Isolation', () {
    testWidgets('Owner and Manager see Marketing tab; Kitchen staff does NOT', (tester) async {
      final restProvider = RestaurantProvider();
      restProvider.setRoleForTest('owner');

      final adminOrderProvider = AdminOrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
            ChangeNotifierProvider<AdminOrderProvider>.value(value: adminOrderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: AdminPage(),
          ),
        ),
      );

      // Owner should see Marketing in bottom nav
      expect(find.text("Marketing"), findsOneWidget);
      expect(find.text("Analytics"), findsOneWidget);
      expect(find.text("Live Orders"), findsOneWidget);

      // Switch role to kitchen
      restProvider.setRoleForTest('kitchen');
      await tester.pump();

      // Kitchen staff should only have Live Orders and NEVER see Marketing or customer retention data
      expect(find.text("Marketing"), findsNothing);
      expect(find.text("Analytics"), findsNothing);
      expect(find.text("Settings"), findsNothing);
    });
  });

  group('Phase 6 — AdminMarketingPage UI', () {
    testWidgets('Renders all 5 subtabs and restriction banner on Starter plan', (tester) async {
      final restProvider = RestaurantProvider();
      // Set to starter plan
      final starterSub = SubscriptionInfo.fromJson({
        'plan': {
          'id': 'starter',
          'name': 'Starter',
          'features': {
            'marketingAndLoyalty': false,
            'customerRetentionAnalytics': false,
          },
        },
        'subscription': {'status': 'active'},
      });
      restProvider.setSubscriptionForTest(starterSub);

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RestaurantProvider>.value(value: restProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminMarketingPage(),
            ),
          ),
        ),
      );

      // Verify the 5 tabs exist
      expect(find.text("Coupons"), findsOneWidget);
      expect(find.text("Promotions"), findsOneWidget);
      expect(find.text("Loyalty"), findsOneWidget);
      expect(find.text("Referrals"), findsOneWidget);
      expect(find.text("Retention"), findsOneWidget);

      // Verify Starter plan warning banner is present
      expect(
        find.text("Marketing & Loyalty requires a Growth or Premium plan. You are viewing in read-only mode."),
        findsOneWidget,
      );
    });
  });
}
