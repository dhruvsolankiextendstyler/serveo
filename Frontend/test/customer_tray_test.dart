import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pages/cart_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBurger = Item(
    itemId: 'item_burger_01',
    itemName: 'Crispy Veggie Burger',
    itemPrice: 99,
    category: 'Burgers',
    description: 'Crispy vegetable patty with fresh lettuce',
    isAvailable: true,
    imageUrl: null, // Null image test
    isVeg: true,
    dietary: 'Veg',
  );

  final samplePizza = Item(
    itemId: 'item_pizza_02',
    itemName: 'Margherita Pizza',
    itemPrice: 199,
    category: 'Pizza',
    description: 'Classic cheese and tomato sauce pizza',
    isAvailable: true,
    imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591',
    isVeg: true,
    dietary: 'Veg',
  );

  Widget createCartScreenWithProviders({
    required OrderProvider orderProvider,
    ThemeProvider? themeProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => themeProvider ?? ThemeProvider(),
        ),
      ],
      child: const MaterialApp(
        home: CartPage(),
      ),
    );
  }

  group('Bug 4 — Customer Tray & Cart Tests', () {
    testWidgets('1. Opening empty Tray displays proper empty state and Go to Menu button', (tester) async {
      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        createCartScreenWithProviders(orderProvider: orderProvider),
      );

      // Verify empty state is displayed
      expect(find.byKey(const Key('empty_tray_icon')), findsOneWidget);
      expect(find.text('Your tray is empty!'), findsOneWidget);
      expect(find.text('Browse our delicious menu and add items to your tray.'), findsOneWidget);
      expect(find.byKey(const Key('go_to_menu_button')), findsOneWidget);
      expect(find.text('Go to Menu'), findsOneWidget);

      // Bill details should NOT be rendered when empty
      expect(find.text('Bill Details'), findsNothing);
    });

    testWidgets('2. Adding item displays name, quantity, price, and subtotal correctly', (tester) async {
      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        createCartScreenWithProviders(orderProvider: orderProvider),
      );

      // Add item to cart
      orderProvider.addToCart(sampleBurger, tester.element(find.byType(CartPage)));
      await tester.pumpAndSettle();

      // Verify item details
      expect(find.byKey(const Key('cart_item_title_item_burger_01')), findsOneWidget);
      expect(find.text('Crispy Veggie Burger'), findsOneWidget);
      expect(find.byKey(const Key('cart_qty_item_burger_01')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byKey(const Key('cart_item_subtotal_item_burger_01')), findsOneWidget);
      expect(find.text('₹99'), findsWidgets);

      // Total amount should be 99
      expect(orderProvider.getTotal(), 99);
      expect(find.textContaining('Proceed to Pay'), findsOneWidget);
    });

    testWidgets('3. Quantity increment and decrement works within limits', (tester) async {
      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        createCartScreenWithProviders(orderProvider: orderProvider),
      );

      orderProvider.addToCart(sampleBurger, tester.element(find.byType(CartPage)));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(orderProvider.getTotal(), 99);

      // Tap increment button
      final incrementBtn = find.byKey(const Key('cart_increment_item_burger_01'));
      await tester.tap(incrementBtn);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(orderProvider.getTotal(), 198);
      expect(find.text('₹198'), findsWidgets);

      // Increment to max (3)
      await tester.tap(incrementBtn);
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(orderProvider.getTotal(), 297);

      // Decrement back to 2
      final decrementBtn = find.byKey(const Key('cart_decrement_item_burger_01'));
      await tester.tap(decrementBtn);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(orderProvider.getTotal(), 198);

      // Decrement to 1
      await tester.tap(decrementBtn);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(orderProvider.getTotal(), 99);

      // Decrement to 0 removes item and restores empty state
      await tester.tap(decrementBtn);
      await tester.pumpAndSettle();

      expect(orderProvider.orderItems.isEmpty, isTrue);
      expect(find.text('Your tray is empty!'), findsOneWidget);
    });

    testWidgets('4. Handles items with null and non-null imageUrl without crashing', (tester) async {
      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        createCartScreenWithProviders(orderProvider: orderProvider),
      );

      // Add item without image
      orderProvider.addToCart(sampleBurger, tester.element(find.byType(CartPage)));
      // Add item with image
      orderProvider.addToCart(samplePizza, tester.element(find.byType(CartPage)));
      await tester.pumpAndSettle();

      expect(find.text('Crispy Veggie Burger'), findsOneWidget);
      expect(find.text('Margherita Pizza'), findsOneWidget);
      expect(orderProvider.orderItems.length, 2);
      expect(orderProvider.getTotal(), 298); // 99 + 199
    });

    testWidgets('5. Defensive fallback renders safely when OrderProvider is absent', (tester) async {
      // Intentionally render CartPage WITHOUT OrderProvider ancestor
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ],
            child: const CartPage(),
          ),
        ),
      );

      // Should not throw ProviderNotFoundException, instead renders graceful fallback
      expect(find.text('Unable to load tray state.'), findsOneWidget);
      expect(find.text('Return to Menu'), findsOneWidget);
    });

    testWidgets('6. Removing item explicitly removes it from tray and recalculates total', (tester) async {
      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        createCartScreenWithProviders(orderProvider: orderProvider),
      );

      orderProvider.addToCart(sampleBurger, tester.element(find.byType(CartPage)));
      orderProvider.addToCart(samplePizza, tester.element(find.byType(CartPage)));
      await tester.pumpAndSettle();

      expect(orderProvider.orderItems.length, 2);
      expect(orderProvider.getTotal(), 298);

      // Explicitly remove sampleBurger
      orderProvider.removeItem(sampleBurger);
      await tester.pumpAndSettle();

      expect(orderProvider.orderItems.length, 1);
      expect(find.text('Crispy Veggie Burger'), findsNothing);
      expect(find.text('Margherita Pizza'), findsOneWidget);
      expect(orderProvider.getTotal(), 199);

      // Clear cart
      orderProvider.clearCart();
      await tester.pumpAndSettle();

      expect(orderProvider.orderItems.isEmpty, isTrue);
      expect(find.text('Your tray is empty!'), findsOneWidget);
    });

    testWidgets('7. Navigation between Menu and Tray does not lose cart state', (tester) async {
      final orderProvider = OrderProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_tray_button'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider<OrderProvider>.value(
                              value: orderProvider,
                              child: const CartPage(),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Tray'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Add item to cart prior to navigation
      orderProvider.addToCart(sampleBurger, tester.element(find.byKey(const Key('open_tray_button'))));
      await tester.pumpAndSettle();

      // Navigate to Tray
      await tester.tap(find.byKey(const Key('open_tray_button')));
      await tester.pumpAndSettle();

      // Verify item exists on Tray screen
      expect(find.text('Crispy Veggie Burger'), findsOneWidget);
      expect(find.text('₹99'), findsWidgets);

      // Pop back to menu
      Navigator.pop(tester.element(find.byType(CartPage)));
      await tester.pumpAndSettle();

      // Ensure item is still in OrderProvider
      expect(orderProvider.orderItems.length, 1);
      expect(orderProvider.getTotal(), 99);

      // Navigate back to Tray
      await tester.tap(find.byKey(const Key('open_tray_button')));
      await tester.pumpAndSettle();

      expect(find.text('Crispy Veggie Burger'), findsOneWidget);
    });
  });
}
