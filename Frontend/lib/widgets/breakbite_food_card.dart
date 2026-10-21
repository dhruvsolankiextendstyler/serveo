import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';

IconData getCategoryIcon(String category) {
  switch (category.toLowerCase().trim()) {
    case 'all':
      return Icons.restaurant_menu;
    case 'burgers':
    case 'burger':
      return Icons.lunch_dining;
    case 'pizza':
      return Icons.local_pizza;
    case 'sandwiches':
    case 'sandwich':
      return Icons.bakery_dining;
    case 'snacks':
    case 'snack':
      return Icons.fastfood;
    case 'beverages':
    case 'beverage':
    case 'drinks':
      return Icons.local_cafe;
    case 'desserts':
    case 'dessert':
      return Icons.cake;
    case 'south indian':
    case 'thali':
      return Icons.dinner_dining;
    default:
      return Icons.restaurant;
  }
}

class ServeoFoodCard extends StatelessWidget {
  final Item item;
  final String imagePath;

  const ServeoFoodCard({
    super.key,
    required this.item,
    required this.imagePath,
  });

  Widget _buildFallbackBanner() {
    final icon = getCategoryIcon(item.category);
    return Container(
      height: 135,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF282828),
            Color(0xFF161616),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 80,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.yellow.withOpacity(0.25), width: 1),
                  ),
                  child: Icon(icon, color: Colors.yellow, size: 30),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final int currentQty = orderProvider.getItemQuantity(item.itemId);
    final bool isSoldOut = !item.isAvailable;

    Widget cardBody = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: currentQty > 0
              ? Colors.yellow
              : (isSoldOut ? Colors.white10 : Colors.white12),
          width: currentQty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: currentQty > 0
            ? [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔹 Food Banner (Image or Category Placeholder)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imagePath.isNotEmpty
                    ? Image.asset(
                        imagePath,
                        height: 135,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(),
                      )
                    : _buildFallbackBanner(),
              ),
              if (isSoldOut)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          "SOLD OUT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // 🔹 Food Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // 🔹 Description (fixed maxLines so cards stay balanced)
                SizedBox(
                  height: 34,
                  child: Text(
                    (item.description != null && item.description!.isNotEmpty)
                        ? item.description!
                        : item.category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 🔹 Price + Add / Quantity Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "₹${item.itemPrice}",
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Controls
                    if (isSoldOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Text(
                          "Unavailable",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (currentQty == 0)
                      ElevatedButton.icon(
                        onPressed: () => orderProvider.addToCart(item, context),
                        icon: const Icon(Icons.add, size: 15, color: Colors.black),
                        label: const Text(
                          "ADD",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => orderProvider.decrementQuantity(item),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Icon(Icons.remove, color: Colors.black, size: 16),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                "$currentQty",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => orderProvider.addToCart(item, context),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Icon(Icons.add, color: Colors.black, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isSoldOut) {
      return Opacity(
        opacity: 0.65,
        child: cardBody,
      );
    }
    return cardBody;
  }
}

typedef BreakbiteFoodCard = ServeoFoodCard;