import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/menu_provider.dart';
import '../utils/order_provider.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_appbar.dart';
import '../widgets/breakbite_drawer.dart';
import '../widgets/breakbite_food_card.dart';
import '../widgets/breakbite_spinner.dart';
import '../widgets/serveo_glass_container.dart';
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
  bool _isSearchOpen = false;
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
        RestaurantProvider? restProvider;
        try {
          restProvider = context.read<RestaurantProvider>();
          restProvider?.fetchPublicInfo();
        } catch (_) {}
        final restId = restProvider?.config.id;
        context.read<MenuProvider>().fetchCampaigns(restaurantId: restId);
        context.read<MenuProvider>().fetchRecommendations(restaurantId: restId);
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
      _isSearchOpen = false;
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
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.yellow : unselectedBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? Colors.yellow : unselectedBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.yellow.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.black : unselectedText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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

  Widget _buildCampaignsBanner(BuildContext context, MenuProvider menuProvider, bool isDark) {
    final campaigns = menuProvider.activeCampaigns;
    if (campaigns.isEmpty) return const SizedBox.shrink();

    final c = campaigns.first;
    final title = c['title']?.toString() ?? "Special Offer";
    final desc = c['description']?.toString() ?? "";
    final code = c['couponCode']?.toString() ?? "";
    final terms = c['termsAndConditions']?.toString() ?? "Valid for a limited time at participating restaurant.";

    return Container(
      key: const Key('active_campaigns_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFFB45309).withValues(alpha: 0.35), const Color(0xFF1E1E1E)]
              : [const Color(0xFFFDE68A), Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.celebration_outlined, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      tooltip: "Terms & Conditions",
                      color: isDark ? Colors.white60 : Colors.black54,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        showGlassDialog(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            content: Text(terms),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text("Got it"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: Text(
                      "Promo Code: $code",
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularItemsSection(
    BuildContext context,
    MenuProvider menuProvider,
    OrderProvider orderProvider,
    bool isDark,
  ) {
    final items = menuProvider.recommendedItems.isNotEmpty
        ? menuProvider.recommendedItems
        : menuProvider.menuItems.take(5).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            Text(
              "POPULAR ITEMS",
              style: TextStyle(
                color: isDark ? Colors.yellow : const Color(0xFFD97706),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 66,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 170,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: item.isVeg ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "₹${item.itemPrice}",
                            style: TextStyle(
                              color: isDark ? Colors.yellow : const Color(0xFFD97706),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () => orderProvider.addToCart(item, context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      child: const Text("+ ADD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingClosedBanner(RestaurantConfig restConfig, bool isDark) {
    if (restConfig.canOrder) return const SizedBox.shrink();

    final isPaused = restConfig.isPaused;
    final title = isPaused ? "Ordering Paused" : "Currently Closed for Orders";
    final subtitle = restConfig.availabilityReason.isNotEmpty
        ? restConfig.availabilityReason
        : (isPaused
            ? "Browsing is available, but checkout is temporarily paused."
            : "Browsing is available. Opens during business hours (${restConfig.operatingHoursFormatted}).");

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          key: const Key('dashboard_restaurant_status_banner'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? (isPaused ? const Color(0xFF2D1E0F) : const Color(0xFF2D1212))
                : (isPaused ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPaused
                  ? const Color(0xFFD97706).withValues(alpha: 0.6)
                  : Colors.redAccent.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isPaused
                      ? const Color(0xFFD97706).withValues(alpha: 0.2)
                      : Colors.redAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaused ? Icons.pause_circle_outline : Icons.schedule,
                  color: isPaused ? const Color(0xFFD97706) : Colors.redAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isPaused
                            ? (isDark ? Colors.amber : const Color(0xFFD97706))
                            : (isDark ? const Color(0xFFFCA5A5) : Colors.redAccent.shade700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    RestaurantProvider? restProvider;
    try {
      restProvider = context.watch<RestaurantProvider>();
    } catch (_) {}
    final restConfig = restProvider?.config ?? RestaurantConfig();

    final categories = _getCategories(menuProvider.menuItems);
    final selectedIndex = categories.indexOf(_selectedCategory);
    final activeIndex = selectedIndex != -1 ? selectedIndex : 0;

    final int cartTotalItems = orderProvider.orderItems.fold(0, (sum, it) => sum + it.quantity);

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);

    final isSearchingOrFiltered = _searchQuery.isNotEmpty || _selectedDietary != "All" || _inStockOnly || _sortBy != "default";

    return Scaffold(
      appBar: ServeoAppBar(
        isSearchActive: _isSearchOpen,
        searchController: _searchController,
        onSearchOpen: () => setState(() => _isSearchOpen = true),
        onSearchClose: () => setState(() {
          _isSearchOpen = false;
          _searchController.clear();
          _searchQuery = "";
        }),
        onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
      drawer: ServeoDrawer(uname: widget.uname),
      body: menuProvider.isLoading
          ? const ServeoSpinner()
          : Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🔹 COMPACT CONTROLS, FILTERS & CATEGORIES
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Desktop-only restaurant title if wide screen
                              if (isDesktop) ...[
                                Row(
                                  children: [
                                    Text(
                                      restConfig.name.isNotEmpty ? restConfig.name : "Serveo",
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (restConfig.description.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "• ${restConfig.description}",
                                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],

                              // 🔹 ANNOUNCEMENT BANNER
                              if (restConfig.announcement.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.campaign_outlined, color: Color(0xFFD97706), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          restConfig.announcement,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // 🔹 PROMOTIONAL CAMPAIGNS BANNER (Phase 6)
                              _buildCampaignsBanner(context, menuProvider, isDark),

                              // 🔹 FILTER TOOLBAR (Dietary, Availability & Sort)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
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
                                    _buildFilterChip(
                                      label: "In Stock Only",
                                      icon: Icons.check_circle_outline,
                                      isSelected: _inStockOnly,
                                      isDark: isDark,
                                      onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                                    ),
                                    const SizedBox(width: 6),
                                    ActionChip(
                                      avatar: const Icon(Icons.sort, size: 14, color: Color(0xFFD97706)),
                                      label: Text(
                                        _sortBy == "default" ? "Sort" : _getSortLabel(_sortBy),
                                        style: TextStyle(
                                          color: _sortBy != "default"
                                              ? Colors.black
                                              : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                          fontSize: 11,
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      visualDensity: VisualDensity.compact,
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
                              const SizedBox(height: 8),

                              // 🔹 CATEGORIES & POPULAR (Hidden during search to maximize search items)
                              if (!isSearchingOrFiltered) ...[
                                SizedBox(
                                  height: 44,
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
                                const SizedBox(height: 4),

                                // Compact Quick-Access Popular Items
                                _buildPopularItemsSection(context, menuProvider, orderProvider, isDark),
                              ],
                            ],
                          ),
                        ),

                        // 🔹 FOOD ITEMS DISPLAY AREA (Dominates 60-70% of Viewport)
                        Expanded(
                          child: isSearchingOrFiltered
                              ? _buildFilteredItemsView(menuProvider, isDark, restConfig, restProvider)
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
                                        await Future.wait([
                                          menuProvider.fetchMenu(),
                                          if (restProvider != null) restProvider.fetchPublicInfo(),
                                        ]);
                                      },
                                      child: ListView(
                                        padding: EdgeInsets.fromLTRB(16, 4, 16, !restConfig.canOrder ? 115 : 85),
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                currentCat == "All" ? "All Items" : currentCat,
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: 17,
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
                                          const SizedBox(height: 10),
                                          if (displayedItems.isEmpty)
                                            _buildNoResultsView(isDark)
                                          else
                                            ...displayedItems.map((item) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 14),
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

                // 🔹 FLOATING RESTAURANT STATUS BANNER (Closed / Paused)
                _buildFloatingClosedBanner(restConfig, isDark),
              ],
            ),
      bottomNavigationBar: cartTotalItems > 0
          ? ServeoGlassContainer(
              blur: 14,
              borderRadius: BorderRadius.zero,
              color: isDark ? const Color(0xCC181818) : const Color(0xD9FFFFFF),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _buildFilteredItemsView(
    MenuProvider menuProvider,
    bool isDark,
    RestaurantConfig restConfig,
    RestaurantProvider? restProvider,
  ) {
    final filtered = _filterAndSortItems(menuProvider.menuItems);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return RefreshIndicator(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      color: Colors.yellow,
      onRefresh: () async {
        await Future.wait([
          menuProvider.fetchMenu(),
          if (restProvider != null) restProvider.fetchPublicInfo(),
        ]);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, !restConfig.canOrder ? 115 : 85),
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
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            _buildNoResultsView(isDark)
          else
            ...filtered.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
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