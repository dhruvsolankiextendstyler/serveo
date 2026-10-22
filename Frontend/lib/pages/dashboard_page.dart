import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/menu_provider.dart';
import '../utils/order_provider.dart';
import '../utils/theme_provider.dart';
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
  late final PageController _pageController;
  final ScrollController _categoryScrollController = ScrollController();

  final Map<String, String> imgMap = const {
    "Beverages": "assets/images/bev.png",
    "Snacks": "assets/images/sna.png",
    "Thali": "assets/images/tha.png",
    "South Indian": "assets/images/sou.png",
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

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

  void _scrollToCategory(int index) {
    if (_categoryScrollController.hasClients) {
      final double targetOffset = (index * 96.0) - 80.0;
      _categoryScrollController.animateTo(
        targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildCategoryTile({
    required String category,
    required bool isSelected,
    required int count,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final icon = getCategoryIcon(category);

    final unselectedBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final unselectedBorder = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final unselectedText = isDark ? Colors.white : const Color(0xFF1F2937);
    final iconColor = isSelected
        ? Colors.black
        : (isDark ? Colors.yellow : const Color(0xFFD97706));

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
            color: isSelected ? Colors.yellow : unselectedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.yellow : unselectedBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.yellow.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : (isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]),
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
                    color: iconColor,
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.black.withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$count",
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black87
                              : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
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
                  color: isSelected ? Colors.black : unselectedText,
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
    final isDark = context.watch<ThemeProvider>().isDark;

    final categories = _getCategories(menuProvider.menuItems);

    // Keep _selectedCategory within valid bounds
    final selectedIndex = categories.indexOf(_selectedCategory);
    final activeIndex = selectedIndex != -1 ? selectedIndex : 0;

    final int cartTotalItems = orderProvider.orderItems.fold(0, (sum, it) => sum + it.quantity);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: const ServeoAppBar(),
      drawer: ServeoDrawer(uname: widget.uname),
      body: menuProvider.isLoading
          ? const ServeoSpinner()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔹 TOP HEADER & CATEGORY BAR
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand Header: Product name is Serveo
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.restaurant, color: Colors.yellow, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Serveo",
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.uname.isNotEmpty
                                          ? "Welcome, ${widget.uname}! Swipe or tap to explore categories."
                                          : "Swipe or tap to browse fresh meals & quick snacks",
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Section: Categories Title
                          Row(
                            children: [
                              Text(
                                "CATEGORIES",
                                style: TextStyle(
                                  color: isDark ? Colors.yellow : const Color(0xFFD97706),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Container(height: 1, color: dividerColor)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Category Horizontal Chips
                          SizedBox(
                            height: 72,
                            child: ListView.builder(
                              controller: _categoryScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final isSelected = index == activeIndex;
                                final count = _getItemCount(cat, menuProvider.menuItems);

                                return _buildCategoryTile(
                                  category: cat,
                                  isSelected: isSelected,
                                  count: count,
                                  isDark: isDark,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                    if (_pageController.hasClients) {
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 280),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                    _scrollToCategory(index);
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),

                    // 🔹 HORIZONTALLY SWIPEABLE FOOD ITEMS PAGEVIEW
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: categories.length,
                        physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                        onPageChanged: (index) {
                          setState(() {
                            _selectedCategory = categories[index];
                          });
                          _scrollToCategory(index);
                        },
                        itemBuilder: (context, pageIndex) {
                          final currentCat = categories[pageIndex];
                          final displayedItems = currentCat == "All"
                              ? menuProvider.menuItems
                              : menuProvider.menuItems
                                  .where((it) =>
                                      it.category.toLowerCase() == currentCat.toLowerCase())
                                  .toList();

                          return RefreshIndicator(
                            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            color: Colors.yellow,
                            onRefresh: () async {
                              await menuProvider.fetchMenu();
                            },
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                              children: [
                                // Category Header inside page
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      currentCat == "All" ? "All Items" : currentCat,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "${displayedItems.length} items",
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Food Items Grid / List
                                if (displayedItems.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 60),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        Icon(
                                          getCategoryIcon(currentCat),
                                          color: isDark ? Colors.white24 : Colors.black26,
                                          size: 52,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "No items available in $currentCat",
                                          style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedCategory = "All";
                                            });
                                            if (_pageController.hasClients) {
                                              _pageController.animateToPage(
                                                0,
                                                duration: const Duration(milliseconds: 280),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                            _scrollToCategory(0);
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
                          );
                        },
                      ),
                    ),
                  ],
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