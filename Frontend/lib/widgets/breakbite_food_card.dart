import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
 // Ensure this points to your OrderProvider file

class ServeoFoodCard extends StatelessWidget {
  final Item item; // Pass the whole Item object for easier logic
  final String imagePath;

  const ServeoFoodCard({
    super.key,
    required this.item,
    required this.imagePath
  });

  @override
  Widget build(BuildContext context) {
    // We watch the provider so the card rebuilds when this specific item's quantity changes
    final orderProvider = context.watch<OrderProvider>();
    final int currentQty = orderProvider.getItemQuantity(item.itemId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: Colors.yellow, width: 1),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                imagePath,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  IconData fallbackIcon = Icons.fastfood;
                  switch (item.category.toLowerCase()) {
                    case 'burgers':
                      fallbackIcon = Icons.lunch_dining;
                      break;
                    case 'pizza':
                      fallbackIcon = Icons.local_pizza;
                      break;
                    case 'sandwiches':
                      fallbackIcon = Icons.bakery_dining;
                      break;
                    case 'snacks':
                      fallbackIcon = Icons.fastfood;
                      break;
                    case 'beverages':
                      fallbackIcon = Icons.local_cafe;
                      break;
                    case 'desserts':
                      fallbackIcon = Icons.cake;
                      break;
                    case 'south indian':
                    case 'thali':
                      fallbackIcon = Icons.restaurant;
                      break;
                  }
                  return Container(
                    height: 160,
                    width: double.infinity,
                    color: const Color(0xFF252525),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(fallbackIcon, color: Colors.yellow, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          item.category,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 🔹 Title
            Padding(padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [     Text(
              item.itemName,
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // 🔹 Description
            Text(
              (item.description != null && item.description!.isNotEmpty)
                  ? item.description!
                  : item.category,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 Price + Logic-based Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "₹${item.itemPrice}",
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // --- TOGGLE LOGIC ---
                !item.isAvailable
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Unavailable",
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      )
                    : currentQty == 0
                    ? ElevatedButton(
                  onPressed: () => orderProvider.addToCart(item, context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text("+ Add"),
                )
                    : Container(
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove, color: Colors.black, size: 20),
                        onPressed: () => orderProvider.decrementQuantity(item),
                      ),
                      Text(
                        "$currentQty",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add, color: Colors.black, size: 20),
                        onPressed: () => orderProvider.addToCart(item, context),
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
  }
}

typedef BreakbiteFoodCard = ServeoFoodCard;