import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
import '../utils/theme_provider.dart';

class CartItemCard extends StatelessWidget {
  final Item item;

  const CartItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final iconBg = isDark ? Colors.black : const Color(0xFFF3F4F6);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // 1. Food Icon / Placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.yellow.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.fastfood, color: Colors.yellow, size: 28),
          ),

          const SizedBox(width: 16),

          // 2. Name and Price info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${item.itemPrice * item.quantity}",
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // 3. The Quantity Toggle (- 2 +)
          Container(
            decoration: BoxDecoration(
              color: Colors.yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                _buildIconButton(
                  icon: Icons.remove,
                  onTap: () => orderProvider.decrementQuantity(item),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "${item.quantity}",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                _buildIconButton(
                  icon: Icons.add,
                  onTap: () => orderProvider.addToCart(item, context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to keep the main tree clean
  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }
}