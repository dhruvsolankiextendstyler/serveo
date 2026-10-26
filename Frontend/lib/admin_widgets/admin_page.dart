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
import 'admin_notification_overlay.dart';
import 'admin_order_details.dart';
import 'admin_report_page.dart';
import '../utils/theme_provider.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminOrderProvider>().startPolling();
      }
    });
  }

  @override
  void dispose() {
    AdminNotificationOverlay.hide();
    super.dispose();
  }

  void _handleLogout(BuildContext context) async {
    final orderProvider = context.read<AdminOrderProvider>();
    final navigator = Navigator.of(context);

    bool? confirm = await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Logout", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to sign out?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text("Logout", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm == true) {
      AdminNotificationOverlay.hide();
      orderProvider.stopPolling();
      await FirebaseAuth.instance.signOut();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<AdminOrderProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    // Check if a global floating alert should be triggered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (orderProvider.pendingAlertOrder != null) {
        AdminNotificationOverlay.show(
          context: context,
          order: orderProvider.pendingAlertOrder!,
          onDismiss: () {
            orderProvider.dismissAlert(orderProvider.pendingAlertOrder!.id);
          },
        );
      }
    });

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

    final pendingVerifications = orderProvider.pendingVerificationOrders;

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
      body: Column(
        children: [
          // Persistent Pending Verification Alert Banner (stays accessible even if overlay dismissed)
          if (pendingVerifications.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFD97706).withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${pendingVerifications.length} UPI order(s) awaiting payment verification",
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChangeNotifierProvider.value(
                            value: orderProvider,
                            child: AdminOrderDetailsPage(order: pendingVerifications.first),
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Review",
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF181818) : Colors.white,
        selectedItemColor: isDark ? Colors.yellow : const Color(0xFFD97706),
        unselectedItemColor: isDark ? Colors.white60 : const Color(0xFF6B7280),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: pendingVerifications.isNotEmpty,
              backgroundColor: const Color(0xFFD97706),
              label: Text(
                "${pendingVerifications.length}",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              child: const Icon(Icons.dashboard),
            ),
            label: "Live Orders",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          const BottomNavigationBarItem(icon: Icon(Icons.list), label: "Add Item"),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Report"),
        ],
      ),
    );
  }
}