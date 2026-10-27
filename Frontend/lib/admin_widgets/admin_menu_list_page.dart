import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/breakbite_spinner.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/order_provider.dart';
import 'item_form_page.dart';

class AdminMenuListPage extends StatefulWidget {
  final http.Client? mockHttpClient;
  final List<Item>? initialItems;

  const AdminMenuListPage({
    super.key,
    this.mockHttpClient,
    this.initialItems,
  });

  @override
  State<AdminMenuListPage> createState() => _AdminMenuListPageState();
}

class _AdminMenuListPageState extends State<AdminMenuListPage> {
  List<Item> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Set<String> _togglingItemIds = {};

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _categories = [
    "All",
    "Burgers",
    "Pizza",
    "Sandwiches",
    "Snacks",
    "Beverages",
    "Desserts",
    "Thali",
    "South Indian"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _items = List<Item>.from(widget.initialItems!);
      _isLoading = false;
    } else {
      _fetchItems();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? token;
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      final headers = {
        if (token != null) "Authorization": "Bearer $token",
      };

      final client = widget.mockHttpClient;
      final response = await (client != null
          ? client.get(
              Uri.parse("${ApiConfig.baseUrl}/item"),
              headers: headers,
            )
          : http.get(
              Uri.parse("${ApiConfig.baseUrl}/item"),
              headers: headers,
            ).timeout(const Duration(seconds: 12)));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] is List) {
          final List<dynamic> list = decoded['message'];
          setState(() {
            _items = list.map((json) => Item.fromJson(json)).toList();
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = "Unexpected response format from server.";
          });
        }
      } else {
        String errDetail = "Failed to load menu (${response.statusCode})";
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && (decoded['error'] != null || decoded['message'] != null)) {
            errDetail = (decoded['error'] ?? decoded['message']).toString();
          }
        } catch (_) {}

        setState(() {
          _isLoading = false;
          _errorMessage = errDetail;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Connection error: Unable to reach backend server ($e).";
      });
    }
  }

  Future<void> _toggleAvailability(Item item) async {
    if (item.itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot update availability: Item ID is missing."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_togglingItemIds.contains(item.itemId)) return;

    setState(() {
      _togglingItemIds.add(item.itemId);
    });

    final newStatus = !item.isAvailable;

    try {
      String? token;
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      final client = widget.mockHttpClient;
      final response = await (client != null
          ? client.put(
              Uri.parse("${ApiConfig.baseUrl}/item/${item.itemId}"),
              headers: {
                "Content-Type": "application/json",
                if (token != null) "Authorization": "Bearer $token",
              },
              body: jsonEncode({"isAvailable": newStatus}),
            )
          : http.put(
              Uri.parse("${ApiConfig.baseUrl}/item/${item.itemId}"),
              headers: {
                "Content-Type": "application/json",
                if (token != null) "Authorization": "Bearer $token",
              },
              body: jsonEncode({"isAvailable": newStatus}),
            ).timeout(const Duration(seconds: 10)));

      if (!mounted) return;

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      final bodyTrimmed = response.body.trim();
      final isHtml = contentType.contains('text/html') ||
          bodyTrimmed.startsWith('<!DOCTYPE') ||
          bodyTrimmed.startsWith('<!doctype') ||
          bodyTrimmed.startsWith('<html');

      if (response.statusCode == 200 && !isHtml) {
        bool confirmedStatus = newStatus;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['item'] is Map && decoded['item']['isAvailable'] != null) {
            confirmedStatus = decoded['item']['isAvailable'] == true;
          }
        } catch (_) {}

        // Requirement: Update UI only after successful server response
        setState(() {
          final index = _items.indexWhere((it) => it.itemId == item.itemId);
          if (index != -1) {
            _items[index] = _items[index].copyWith(isAvailable: confirmedStatus);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "'${item.itemName}' is now ${confirmedStatus ? 'Available' : 'Sold Out'}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: confirmedStatus ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        String errDetail = isHtml
            ? "Server error (${response.statusCode}): Received HTML error page"
            : "Failed to update availability (${response.statusCode})";
        if (!isHtml) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && (decoded['error'] != null || decoded['message'] != null)) {
              errDetail = (decoded['error'] ?? decoded['message']).toString();
            }
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errDetail), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglingItemIds.remove(item.itemId);
        });
      }
    }
  }

  Future<void> _confirmAndDeleteItem(Item item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          title: Text(
            "Delete Item",
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1F2937), fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to delete '${item.itemName}'? This action cannot be undone.",
            style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      String? token;
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      final response = await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/item/${item.itemId}"),
        headers: {
          if (token != null) "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _items.removeWhere((it) => it.itemId == item.itemId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Item '${item.itemName}' deleted successfully",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        String errDetail = "Failed to delete item (${response.statusCode})";
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && (decoded['error'] != null || decoded['message'] != null)) {
            errDetail = (decoded['error'] ?? decoded['message']).toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errDetail), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _openAddItemForm() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text("Add New Item"),
          ),
          body: const ItemFormPage(),
        ),
      ),
    );

    if (result == true) {
      _fetchItems();
    }
  }

  Future<void> _openEditItemForm(Item item) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text("Edit Item"),
          ),
          body: ItemFormPage(editingItem: item),
        ),
      ),
    );

    if (result == true) {
      _fetchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final brandColor = isDark ? Colors.yellow : const Color(0xFFD97706);

    final filteredItems = _items.where((it) {
      final matchesCategory = _selectedCategory == 'All' ||
          it.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          it.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          it.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('admin_add_item_fab'),
        onPressed: _openAddItemForm,
        backgroundColor: brandColor,
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Item",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchItems,
        color: brandColor,
        child: Column(
          children: [
            // Header: "Menu List" + Count + Refresh Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "Menu List",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brandColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          "${filteredItems.length} items",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: brandColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: "Refresh Menu",
                    onPressed: _fetchItems,
                    color: brandColor,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: primaryTextColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search menu items...",
                  hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                  prefixIcon: Icon(Icons.search, size: 20, color: secondaryTextColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),

            // Category Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: brandColor,
                        backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                        checkmarkColor: isDark ? Colors.black : Colors.white,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? brandColor
                                : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                          ),
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Content Area: Loading, Error, Empty, or List
            Expanded(
              child: _isLoading
                  ? const Center(child: ServeoSpinner())
                  : _errorMessage != null
                      ? _buildErrorState(primaryTextColor, brandColor)
                      : filteredItems.isEmpty
                          ? _buildEmptyState(isDark)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _buildMenuItemCard(
                                  item: item,
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                  brandColor: brandColor,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard({
    required Item item,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandColor,
  }) {
    final hasImage = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;
    final resolvedUrl = ApiConfig.resolveImageUrl(item.imageUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isAvailable ? borderColor : Colors.redAccent.withValues(alpha: 0.3),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Food Image or Placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 68,
                height: 68,
                color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
                child: hasImage
                    ? Image.network(
                        resolvedUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => _buildImagePlaceholder(isDark),
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                    : _buildImagePlaceholder(isDark),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Info: Name, Category, Price, Availability
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Availability Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isAvailable
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: item.isAvailable
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          item.isAvailable ? "Available" : "Sold Out",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.isAvailable
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${item.itemPrice}",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: brandColor,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Actions: Toggle Availability, Edit, Delete
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Availability Switch
                Transform.scale(
                  scale: 0.75,
                  child: Switch.adaptive(
                    key: Key('item_switch_${item.itemId}'),
                    value: item.isAvailable,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: _togglingItemIds.contains(item.itemId)
                        ? null
                        : (val) => _toggleAvailability(item),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: "Edit Item",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: secondaryTextColor,
                      onPressed: () => _openEditItemForm(item),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: "Delete Item",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: Colors.redAccent,
                      onPressed: () => _confirmAndDeleteItem(item),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Center(
      child: Icon(
        Icons.fastfood_rounded,
        size: 32,
        color: isDark ? Colors.white24 : Colors.grey[400],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "No Menu Items Found",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != 'All'
                  ? "Try clearing filters to see all menu items."
                  : "Tap the + button below to add your first menu item.",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color primaryTextColor, Color brandColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              "Failed to Load Menu",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryTextColor),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? "An unexpected error occurred.",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchItems,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
