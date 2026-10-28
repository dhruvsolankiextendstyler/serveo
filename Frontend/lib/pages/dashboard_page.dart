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
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String _searchQuery = "";
  String _selectedDietary = "All"; // "All" | "Veg" | "Non-Veg"
  bool _inStockOnly = false;
  String _sortBy = "default"; // "default" | "price_asc" | "price_desc" | "name_asc" | "name_desc"

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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrderProvider>().fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = "";
      _selectedCategory = "All";
      _selectedDietary = "All";
      _inStockOnly = false;
      _sortBy = "default";
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedDietary != "All" ||
      _inStockOnly ||
      _sortBy != "default" ||
      _selectedCategory != "All";

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

  List<Item> _filterAndSortItems(List<Item> items, {String? categoryOverride}) {
    final cat = categoryOverride ?? _selectedCategory;

    return items.where((it) {
      // 1. Category Filter
      if (cat != "All" && it.category.toLowerCase() != cat.toLowerCase()) {
        return false;
      }

      // 2. Search Query (Case-insensitive match on name, description, category)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = it.itemName.toLowerCase().contains(q);
        final matchesDesc = (it.description ?? "").toLowerCase().contains(q);
        final matchesCat = it.category.toLowerCase().contains(q);
        if (!matchesName && !matchesDesc && !matchesCat) {
          return false;
        }
      }

      // 3. Dietary Filter
      if (_selectedDietary == "Veg" && !it.isVeg) {
        return false;
      }
      if (_selectedDietary == "Non-Veg" && it.isVeg) {
        return false;
      }

      // 4. Availability Filter
      if (_inStockOnly && !it.isAvailable) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        switch (_sortBy) {
          case "price_asc":
            return a.itemPrice.compareTo(b.itemPrice);
          case "price_desc":
            return b.itemPrice.compareTo(a.itemPrice);
          case "name_asc":
            return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
          case "name_desc":
            return b.itemName.toLowerCase().compareTo(a.itemName.toLowerCase());
          default:
            return 0;
        }
      });
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

  void _showSortDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    "Sort Menu Items",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
                _buildSortOption("Default", "default", isDark),
                _buildSortOption("Price: Low to High", "price_asc", isDark),
                _buildSortOption("Price: High to Low", "price_desc", isDark),
                _buildSortOption("Name: A to Z", "name_asc", isDark),
                _buildSortOption("Name: Z to A", "name_desc", isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value, bool isDark) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFFD97706) : (isDark ? Colors.white : const Color(0xFF1F2937)),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFD97706)) : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    final categories = _getCategories(menuProvider.menuItems);

    final selectedIndex = categories.indexOf(_selectedCategory);
    final activeIndex = selectedIndex != -1 ? selectedIndex : 0;

    final int cartTotalItems = orderProvider.orderItems.fold(0, (sum, it) => sum + it.quantity);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    final isSearchingOrFiltered = _searchQuery.isNotEmpty || _selectedDietary != "All" || _inStockOnly || _sortBy != "default";

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
                    // 🔹 TOP HEADER, SEARCH BAR & FILTER TOOLBAR
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                                          ? "Welcome, ${widget.uname}! Fresh meals & fast service."
                                          : "Fresh meals & quick snacks ready for counter pickup",
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
                          const SizedBox(height: 12),

                          // 🔹 SEARCH INPUT FIELD
                          Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _searchQuery.isNotEmpty
                                    ? Colors.yellow
                                    : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search dishes, snacks & drinks...",
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFFD97706)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        color: isDark ? Colors.white60 : Colors.black45,
                                        onPressed: () => _searchController.clear(),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 🔹 FILTER TOOLBAR (Dietary, Availability & Sort)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // Dietary Filter: All / Veg / Non-Veg
                                _buildFilterChip(
                                  label: "All",
                                  isSelected: _selectedDietary == "All",
                                  isDark: isDark,
                                  onTap: () => setState(() => _selectedDietary = "All"),
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  label: "Veg Only",
                                  icon: Icons.eco,
                                  iconColor: Colors.green,
                                  isSelected: _selectedDietary == "Veg",
                                  isDark: isDark,
                                  onTap: () => setState(() => _selectedDietary = "Veg"),
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  label: "Non-Veg",
                                  isSelected: _selectedDietary == "Non-Veg",
                                  isDark: isDark,
                                  onTap: () => setState(() => _selectedDietary = "Non-Veg"),
                                ),
                                const SizedBox(width: 6),

                                // In Stock Only toggle
                                _buildFilterChip(
                                  label: "In Stock Only",
                                  icon: Icons.check_circle_outline,
                                  isSelected: _inStockOnly,
                                  isDark: isDark,
                                  onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                                ),
                                const SizedBox(width: 6),

                                // Sort Button
                                ActionChip(
                                  avatar: const Icon(Icons.sort, size: 16, color: Color(0xFFD97706)),
                                  label: Text(
                                    _sortBy == "default" ? "Sort" : _getSortLabel(_sortBy),
                                    style: TextStyle(
                                      color: _sortBy != "default"
                                          ? Colors.black
                                          : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                      fontSize: 12,
                                      fontWeight: _sortBy != "default" ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  backgroundColor: _sortBy != "default"
                                      ? Colors.yellow
                                      : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                  side: BorderSide(
                                    color: _sortBy != "default"
                                        ? Colors.yellow
                                        : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  onPressed: () => _showSortDialog(isDark),
                                ),

                                if (_hasActiveFilters) ...[
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: _resetAllFilters,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      "Reset",
                                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

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
                          const SizedBox(height: 8),

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
                                    if (_pageController.hasClients && !isSearchingOrFiltered) {
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // 🔹 FOOD ITEMS DISPLAY AREA
                    Expanded(
                      child: isSearchingOrFiltered
                          ? _buildFilteredItemsView(menuProvider, isDark)
                          : PageView.builder(
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
                                final displayedItems = _filterAndSortItems(menuProvider.menuItems, categoryOverride: currentCat);

                                return RefreshIndicator(
                                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  color: Colors.yellow,
                                  onRefresh: () async {
                                    await menuProvider.fetchMenu();
                                  },
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                                    children: [
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
                                            "${displayedItems.length} available",
                                            style: TextStyle(
                                              color: secondaryTextColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (displayedItems.isEmpty)
                                        _buildNoResultsView(isDark)
                                      else
                                        ...displayedItems.map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            child: ServeoFoodCard(
                                              item: item,
                                              imagePath: imgMap[item.category] ?? "",
                                            ),
                                          );
                                        }),
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
      bottomNavigationBar: cartTotalItems > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181818) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$cartTotalItems ${cartTotalItems == 1 ? 'ITEM' : 'ITEMS'} IN TRAY",
                          style: TextStyle(
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          "₹${orderProvider.getTotal()}",
                          style: TextStyle(
                            color: isDark ? Colors.yellow : const Color(0xFFD97706),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      key: const Key('dashboard_view_tray_btn'),
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
                      icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 18),
                      label: const Text(
                        "VIEW TRAY",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilteredItemsView(MenuProvider menuProvider, bool isDark) {
    final filtered = _filterAndSortItems(menuProvider.menuItems);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return RefreshIndicator(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      color: Colors.yellow,
      onRefresh: () async {
        await menuProvider.fetchMenu();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchQuery.isNotEmpty ? "Results for '$_searchQuery'" : "Filtered Items",
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${filtered.length} found",
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _buildNoResultsView(isDark)
          else
            ...filtered.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ServeoFoodCard(
                  item: item,
                  imagePath: imgMap[item.category] ?? "",
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNoResultsView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            "No matching menu items found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try adjusting your search terms, dietary filters, or selected category.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _resetAllFilters,
            icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
            label: const Text(
              "Reset All Filters",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    Color? iconColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.yellow : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.black : (iconColor ?? const Color(0xFFD97706))),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case "price_asc":
        return "Price: Low";
      case "price_desc":
        return "Price: High";
      case "name_asc":
        return "A-Z";
      case "name_desc":
        return "Z-A";
      default:
        return "Sort";
    }
  }
}