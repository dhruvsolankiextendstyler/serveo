import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/pages/cart_page.dart';
import 'package:frontend/pages/order_history_page.dart';
import 'package:frontend/pages/login_page.dart';
import 'package:frontend/pages/report_page.dart';
import 'package:frontend/pages/customer_referral_page.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/restaurant_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart';
import '../utils/api_config.dart';

class ServeoDrawer extends StatelessWidget {
  final String uname;

  const ServeoDrawer({super.key, required this.uname});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    final bgColor = isDark ? const Color(0xFF161616) : Colors.white;
    final headerBgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF3F4F6);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Drawer(
      backgroundColor: bgColor,
      child: Column(
        children: [
          // 1. The Header (Profile Area)
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: headerBgColor,
            ),
            accountName: Text(
              uname.isNotEmpty ? uname : "Serveo User",
              style: TextStyle(
                color: isDark ? Colors.yellow : const Color(0xFFD97706),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: Text(
              FirebaseAuth.instance.currentUser?.email ?? "student@college.edu",
              style: TextStyle(color: subtextColor),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.yellow,
              child: Text(
                uname.isNotEmpty ? uname[0].toUpperCase() : "U",
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 2. Navigation Items
          _buildDrawerItem(
            context,
            icon: Icons.fastfood,
            title: "Menu",
            textColor: textColor,
            onTap: () => Navigator.pop(context),
          ),

          _buildDrawerItem(
            context,
            icon: Icons.shopping_cart,
            title: "My Cart",
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider.value(
                    value: orderProvider,
                    child: const CartPage(),
                  ),
                ),
              );
            },
          ),

          _buildDrawerItem(
            context,
            icon: Icons.history,
            title: "Order History",
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChangeNotifierProvider.value(
                    value: orderProvider,
                    child: const OrderHistoryPage(),
                  ),
                ),
              );
            },
          ),

          _buildDrawerItem(
            context,
            icon: Icons.card_giftcard,
            title: "Refer & Earn",
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CustomerReferralPage(),
                ),
              );
            },
          ),

          _buildDrawerItem(
            context,
            icon: Icons.bar_chart,
            title: "Analytics",
            textColor: textColor,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ReportPage(),
                ),
              );
            },
          ),

          Divider(color: dividerColor),

          // 3. Theme Toggle Item (Mobile)
          ListTile(
            leading: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.yellow : const Color(0xFFD97706),
            ),
            title: Text(
              isDark ? "Light mode" : "Dark mode",
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Switch.adaptive(
              value: !isDark,
              activeThumbColor: Colors.yellow,
              activeTrackColor: Colors.yellow.withValues(alpha: 0.5),
              onChanged: (_) {
                context.read<ThemeProvider>().toggleTheme();
              },
            ),
            onTap: () {
              context.read<ThemeProvider>().toggleTheme();
            },
          ),

          const Spacer(),
          Divider(color: dividerColor),

          // 4. Logout Button
          _buildDrawerItem(
            context,
            icon: Icons.logout,
            title: "Log Out",
            iconColor: Colors.redAccent,
            textColor: Colors.redAccent,
            onTap: () async {
              final user = FirebaseAuth.instance.currentUser;

              if (user != null) {
                try {
                  final token = await user.getIdToken();
                  await patch(
                    Uri.parse("${ApiConfig.baseUrl}/user/clear-fcm"),
                    headers: {
                      "Content-Type": "application/json",
                      "Authorization": "Bearer $token",
                    },
                  );
                } catch (e) {
                  // Ignore token clearing error
                }
              }
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Builder(builder: (ctx) {
              RestaurantProvider? restProvider;
              try {
                restProvider = ctx.watch<RestaurantProvider>();
              } catch (_) {}
              final rest = restProvider?.config ?? RestaurantConfig();
              return Text(
                "${rest.name} • Hours: ${rest.openingTime} - ${rest.closingTime}",
                style: TextStyle(color: subtextColor, fontSize: 11),
                textAlign: TextAlign.center,
              );
            }),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.yellow,
    Color textColor = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
      onTap: onTap,
    );
  }
}

typedef BreakBiteDrawer = ServeoDrawer;