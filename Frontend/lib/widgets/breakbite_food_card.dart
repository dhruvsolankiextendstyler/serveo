import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api_config.dart';
import '../utils/order_provider.dart';
import '../utils/theme_provider.dart';

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

  Widget _buildFallbackBanner(bool isDark) {
    final icon = getCategoryIcon(item.category);
    return Container(
      height: 135,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF282828), Color(0xFF161616)]
              : const [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 80,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.yellow.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Colors.yellow : const Color(0xFFD97706),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black45 : Colors.white70,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
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

  Widget _buildFoodImage(bool isDark) {
    final rawUrl = item.imageUrl;
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      final fullUrl = ApiConfig.resolveImageUrl(rawUrl);
      return Image.network(
        fullUrl,
        height: 135,
        width: double.infinity,
        fit: BoxFit.cover, // Ensures images fit their containers without stretching or distorting
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 135,
            color: isDark ? const Color(0xFF282828) : const Color(0xFFF3F4F6),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.yellow),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (imagePath.isNotEmpty) {
            return Image.asset(
              imagePath,
              height: 135,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackBanner(isDark),
            );
          }
          return _buildFallbackBanner(isDark);
        },
      );
    }

    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        height: 135,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackBanner(isDark),
      );
    }

    return _buildFallbackBanner(isDark);
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;
    final int currentQty = orderProvider.getItemQuantity(item.itemId);
    final bool isSoldOut = !item.isAvailable;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = currentQty > 0
        ? Colors.yellow
        : (isSoldOut
            ? (isDark ? Colors.white10 : const Color(0xFFE5E7EB))
            : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)));
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final descTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final priceColor = isDark ? Colors.yellow : const Color(0xFFD97706);

    Widget cardBody = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardBg,
        border: Border.all(
          color: borderColor,
          width: currentQty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: currentQty > 0
            ? [
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : (isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]),
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
                child: _buildFoodImage(isDark),
              ),
              if (isSoldOut)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
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
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // 🔹 Description
                SizedBox(
                  height: 34,
                  child: Text(
                    (item.description != null && item.description!.isNotEmpty)
                        ? item.description!
                        : item.category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: descTextColor,
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
                      style: TextStyle(
                        color: priceColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Controls
                    if (isSoldOut)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          "Unavailable",
                          style: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
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