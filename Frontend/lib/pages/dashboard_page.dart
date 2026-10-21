import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/menu_provider.dart';
import '../utils/order_provider.dart';
import '../widgets/breakbite_appbar.dart';
import '../widgets/breakbite_drawer.dart';
import '../widgets/breakbite_food_card.dart';
import '../widgets/breakbite_spinner.dart';
import 'cart_page.dart';

class DashboardPage extends StatefulWidget {
  final String uname;
  const DashboardPage({super.key, required this.uname});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedCategory = "All";

  final Map<String, String> imgMap = const {
    "Beverages": "assets/images/bev.png",
    "Snacks": "assets/images/sna.png",
    "Thali": "assets/images/tha.png",
    "South Indian": "assets/images/sou.png",
  };

  List<String> _getCategories(List<Item> items) {
    final Set<String> categories = {"All"};
    final preferredOrder = [
      "Burgers",
      "Pizza",
      "Sandwiches",
      "Snacks",
      "Beverages",
      "Desserts",
      "South Indian",
      "Thali",
    ];

    for (var cat in preferredOrder) {
      if (items.any((it) => it.category.toLowerCase() == cat.toLowerCase())) {
        categories.add(cat);
      }
    }

    for (var it in items) {
      if (it.category.trim().isNotEmpty) {
        categories.add(it.category.trim());
      }
    }

    // Fallback if menu items haven't loaded yet
    if (categories.length == 1) {
      categories.addAll(["Burgers", "Pizza", "Sandwiches", "Snacks", "Beverages", "Desserts"]);
    }

    return categories.toList();
  }

  int _getItemCount(String category, List<Item> items) {
    if (category == "All") return items.length;
    return items.where((it) => it.category.toLowerCase() == category.toLowerCase()).length;
  }

  Widget _buildCategoryTile({
    required String category,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    final icon = getCategoryIcon(category);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.yellow : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.yellow : Colors.white12,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.black : Colors.yellow,
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black.withOpacity(0.15) : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$count",
                        style: TextStyle(
                          color: isSelected ? Colors.black87 : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final orderProvider = context.watch<OrderProvider>();

    final categories = _getCategories(menuProvider.menuItems);
    final displayedItems = _selectedCategory == "All"
        ? menuProvider.menuItems
        : menuProvider.menuItems
            .where((it) => it.category.toLowerCase() == _selectedCategory.toLowerCase())
            .toList();

    final int cartTotalItems = orderProvider.orderItems.fold(0, (sum, it) => sum + it.quantity);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const ServeoAppBar(),
      drawer: ServeoDrawer(uname: widget.uname),
      body: menuProvider.isLoading
          ? const ServeoSpinner()
          : RefreshIndicator(
              backgroundColor: Colors.black,
              color: Colors.yellow,
              onRefresh: () async {
                await menuProvider.fetchMenu();
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    children: [
                      // 🔹 HEADER: Title and Subtitle
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.yellow.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant, color: Colors.yellow, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Serveo Canteen",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.uname.isNotEmpty
                                      ? "Welcome, ${widget.uname}! Select a category below to order."
                                      : "Select a category to browse fresh meals & quick snacks",
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 🔹 SECTION: Categories Header
                      Row(
                        children: [
                          const Text(
                            "CATEGORIES",
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 1, color: Colors.white12)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 🔹 PROMINENT CATEGORY SELECTOR (Horizontally scrollable, compact height)
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                            final count = _getItemCount(cat, menuProvider.menuItems);

                            return _buildCategoryTile(
                              category: cat,
                              isSelected: isSelected,
                              count: count,
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔹 SECTION: Menu Items Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory == "All" ? "All Items" : _selectedCategory,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${displayedItems.length} items",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 🔹 FOOD ITEMS PRESENTATION (Responsive grid / list)
                      if (displayedItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                getCategoryIcon(_selectedCategory),
                                color: Colors.white24,
                                size: 52,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No items available in $_selectedCategory",
                                style: const TextStyle(color: Colors.white60, fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = "All";
                                  });
                                },
                                icon: const Icon(Icons.arrow_back, color: Colors.yellow, size: 16),
                                label: const Text(
                                  "View All Items",
                                  style: TextStyle(color: Colors.yellow),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 650;

                            if (isWide) {
                              return Column(
                                children: [
                                  for (int i = 0; i < displayedItems.length; i += 2) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ServeoFoodCard(
                                            item: displayedItems[i],
                                            imagePath: imgMap[displayedItems[i].category] ?? "",
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: (i + 1 < displayedItems.length)
                                              ? ServeoFoodCard(
                                                  item: displayedItems[i + 1],
                                                  imagePath: imgMap[displayedItems[i + 1].category] ?? "",
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  for (var item in displayedItems) ...[
                                    ServeoFoodCard(
                                      item: item,
                                      imagePath: imgMap[item.category] ?? "",
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                ],
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: orderProvider.orderItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider.value(
                      value: orderProvider,
                      child: const CartPage(),
                    ),
                  ),
                );
              },
              backgroundColor: Colors.yellow,
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
              label: Text(
                "View Cart ($cartTotalItems) • ₹${orderProvider.getTotal()}",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            )
          : null,
    );
  }
}