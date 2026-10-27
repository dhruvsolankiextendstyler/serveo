import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_bill_details_card.dart';
import '../widgets/breakbite_cart_item_card.dart';
import 'payment_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider?>(context);
    final themeProvider = Provider.of<ThemeProvider?>(context);
    final isDark = themeProvider?.isDark ?? true;

    if (orderProvider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tray")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Unable to load tray state."),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Return to Menu"),
              ),
            ],
          ),
        ),
      );
    }

    final cartItems = orderProvider.orderItems;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Checkout",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: primaryTextColor,
              ),
            ),
            if (cartItems.isNotEmpty)
              Text(
                "${cartItems.length} items in tray",
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
          ],
        ),
      ),
      body: cartItems.isEmpty
          ? _buildEmptyState(context, isDark)
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Dynamic List
                        ...cartItems.map((item) => CartItemCard(item: item)),

                        const SizedBox(height: 24),

                        // Bill card
                        const BillDetailsCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                _buildProceedToPayButton(context, orderProvider, isDark),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final iconColor = isDark ? Colors.white24 : Colors.black26;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, key: const Key('empty_tray_icon'), size: 84, color: iconColor),
            const SizedBox(height: 16),
            Text(
              "Your tray is empty!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Browse our delicious menu and add items to your tray.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('go_to_menu_button'),
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Go to Menu",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProceedToPayButton(
    BuildContext context,
    OrderProvider provider,
    bool isDark,
  ) {
    final total = provider.getTotal();
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const PaymentPage(),
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Proceed to Pay • ₹$total",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}