import 'package:flutter/material.dart';
import 'package:frontend/widgets/breakbite_drawer.dart';
import 'package:frontend/widgets/breakbite_spinner.dart';
import 'package:provider/provider.dart';

import '../utils/menu_provider.dart';
import '../utils/order_provider.dart';
import '../widgets/breakbite_appbar.dart';
import '../widgets/breakbite_food_card.dart';
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
    final defaultCategories = ["All", "Burgers", "Pizza", "Sandwiches", "Snacks", "Beverages", "Desserts"];
    final Set<String> categories = {"All"};
    for (var cat in defaultCategories) {
      categories.add(cat);
    }
    for (var item in items) {
      if (item.category.isNotEmpty) {
        categories.add(item.category);
      }
    }
    return categories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final orderProvider = context.watch<OrderProvider>();

    final categories = _getCategories(menuProvider.menuItems);
    final displayedItems = _selectedCategory == "All"
        ? menuProvider.menuItems
        : menuProvider.menuItems.where((it) => it.category == _selectedCategory).toList();

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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Welcome, ${widget.uname}!", style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),

            // --- CATEGORY FILTER BAR ---
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.yellow : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.yellow : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- FOOD ITEMS LIST ---
            if (displayedItems.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 60),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.fastfood_outlined, color: Colors.grey, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "No items found in $_selectedCategory",
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              )
            else
              ...displayedItems.map((item) => ServeoFoodCard(
                item: item,
                imagePath: imgMap[item.category] ?? "",
              )),

            const Divider(color: Colors.yellow),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.1,
              child: Center(
                child: Text(
                  "Showing ${displayedItems.length} items",
                  style: TextTheme.of(context).bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
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
        label: Text("View Cart • ₹${orderProvider.getTotal()}"),
        icon: const Icon(Icons.shopping_cart),
        backgroundColor: Colors.yellow,
      ) : null,
    );
  }
}