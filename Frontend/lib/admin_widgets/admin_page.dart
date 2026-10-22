import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend/admin_widgets/item_form_page.dart';
import 'package:frontend/widgets/breakbite_appbar.dart';
import 'package:frontend/widgets/breakbite_spinner.dart';
import '../pages/login_page.dart';
import 'admin_history_page.dart';
import 'admin_live_page.dart';
import 'admin_report_page.dart';
import '../utils/theme_provider.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

  void _handleLogout(BuildContext context) async {
    // Show a confirmation dialog (Optional but professional)
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Logout", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to sign out?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        // Remove all previous routes and go to Login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
              (route) => false,
        );
      }
    }
  }
  // initState is now empty or removed because fetchOrders happens in the Provider creation!

  @override
  Widget build(BuildContext context) {
    // Watch the provider for the loading status
    final orderProvider = context.watch<AdminOrderProvider>();

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    if (orderProvider.isLoading) {
      return const Scaffold(
        appBar: ServeoAppBar(),
        body: Center(child: ServeoSpinner()),
      );
    }

    final screens = [
      const LivePage(),
      const HistoryPage(),
      ItemFormPage(),
      const AdminReportPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? Colors.amber : const Color(0xFF1F2937),
            ),
            tooltip: isDark ? "Switch to Light mode" : "Switch to Dark mode",
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Logout",
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        selectedItemColor: isDark ? Colors.yellow : const Color(0xFFD97706),
        unselectedItemColor: isDark ? Colors.white60 : const Color(0xFF6B7280),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Live Orders"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Add Item"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Report"),
        ],
      ),
    );
  }
}