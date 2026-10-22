import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pages/cart_page.dart';
import 'package:frontend/pages/payment_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme System Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ThemeProvider initializes with dark theme by default', () async {
      final provider = ThemeProvider();
      await provider.loadThemePreference();

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDark, isTrue);
    });

    test('ThemeProvider toggles between dark and light themes', () async {
      final provider = ThemeProvider();
      await provider.loadThemePreference();

      await provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDark, isFalse);

      await provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDark, isTrue);
    });

    test('ThemeProvider loads saved light theme from preferences', () async {
      SharedPreferences.setMockInitialValues({'serveo_theme_mode': 'light'});
      final provider = ThemeProvider();
      await provider.loadThemePreference();

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDark, isFalse);
    });

    test('AppTheme brand colors and overlay styles are correctly configured', () {
      expect(AppTheme.brandYellow, const Color(0xFFFFD600));
      expect(AppTheme.darkBackground, const Color(0xFF121212));
      expect(AppTheme.lightBackground, const Color(0xFFF7F8FA));

      expect(AppTheme.darkOverlayStyle.statusBarIconBrightness, Brightness.light);
      expect(AppTheme.lightOverlayStyle.statusBarIconBrightness, Brightness.dark);
    });
  });

  group('PaymentPage & Demo Flow Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('PaymentPage displays demo banner and mock payment methods', (tester) async {
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: PaymentPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Heading
      expect(find.text("Choose Payment Method"), findsOneWidget);

      // Demo experience notice
      expect(find.text("Demo Payment Experience"), findsOneWidget);
      expect(
        find.textContaining("This is a simulated payment screen for shop demonstrations"),
        findsOneWidget,
      );

      // Mock options
      expect(find.text("UPI (Google Pay, PhonePe, Paytm)"), findsOneWidget);
      expect(find.text("Pay at Counter / Cash"), findsOneWidget);
      expect(find.text("Credit / Debit Card (Mock)"), findsOneWidget);

      // Primary and secondary actions
      expect(find.textContaining("Pay Now"), findsOneWidget);
      expect(find.text("Back to Cart"), findsOneWidget);
    });

    testWidgets('Selecting mock payment option updates selection cleanly', (tester) async {
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: PaymentPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Cash option
      await tester.tap(find.text("Pay at Counter / Cash"));
      await tester.pumpAndSettle();

      expect(find.text("Pay at Counter / Cash"), findsOneWidget);
    });
  });

  group('CartPage Checkout Action Tests', () {
    testWidgets('CartPage displays Proceed to Pay when items exist', (tester) async {
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      // Add a test item directly
      final testItem = Item(
        itemId: "item1",
        itemName: "Veg Burger",
        itemPrice: 120,
        category: "Burgers",
        isAvailable: true,
      )..quantity = 1;
      orderProvider.orderItems.add(testItem);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: CartPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Button must say Proceed to Pay
      expect(find.textContaining("Proceed to Pay"), findsOneWidget);
      // Confirm Order must not exist
      expect(find.text("Confirm Order"), findsNothing);
    });

    testWidgets('CartPage displays empty state when no items in cart', (tester) async {
      final orderProvider = OrderProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: CartPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Your tray is empty!"), findsOneWidget);
      expect(find.text("Go to Menu"), findsOneWidget);
    });
  });
}
