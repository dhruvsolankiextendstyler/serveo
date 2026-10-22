import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/breakbite_spinner.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
// Import your spinner if you have one, or use CircularProgressIndicator
// import 'package:frontend/widgets/spinner.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool isLoading = true;

  // Data variables
  int totalSpent = 0;
  String favouriteItemName = "No orders yet";
  int favouriteItemQuantity = 0;

  @override
  void initState() {
    super.initState();
    fetchUserStats();
  }

  Future<void> fetchUserStats() async {
    setState(() => isLoading = true);

    try {

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/order/userReport"),
        headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      });

      print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['message'];

        setState(() {
          totalSpent = data['totalSpend'] ?? 0;

          final favItem = data['favouriteItem'];
          if (favItem != null) {
            favouriteItemName = favItem['name'] ?? "Unknown Item";
            favouriteItemQuantity = favItem['quantity'] ?? 0;
          }
        });
      }
    } catch (e) {
      print("Error fetching user stats: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Food Stats", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const ServeoSpinner()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Your Serveo Journey",
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Total Spent Card
                  buildStatCard(
                    title: "Total Spent",
                    value: "₹$totalSpent",
                    subtitle: "Lifetime spending",
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 16),

                  // Favourite Item Card
                  buildStatCard(
                    title: "Most Ordered",
                    value: favouriteItemName,
                    subtitle: favouriteItemQuantity > 0
                        ? "Ordered $favouriteItemQuantity times"
                        : "Go place an order!",
                    icon: Icons.favorite,
                    color: Colors.redAccent,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final valueColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: titleColor, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}