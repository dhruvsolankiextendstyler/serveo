import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/widgets/breakbite_spinner.dart';
import 'package:http/http.dart';
import '../utils/api_config.dart';

class AdminReportPage extends StatefulWidget {
  const AdminReportPage({super.key});

  @override
  State<AdminReportPage> createState() => AdminReportPageState();
}

class AdminReportPageState extends State<AdminReportPage> {
  String selectedTimeframe = 'daily'; // Default timeframe
  bool isLoading = true;

  // Data variables
  int totalSales = 0;
  String mostSoldProduct = "N/A";
  String peakHour = "N/A";

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  Future<void> fetchReportData() async {
    setState(() => isLoading = true);

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await get(
        Uri.parse("${ApiConfig.baseUrl}/order/$selectedTimeframe"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        }
      );
      print(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['message'];

        setState(() {
          totalSales = data['totalSales'] ?? 0;
          mostSoldProduct =data['mostSoldProduct']['name'] ?? "N/A";
          final rawHour = data['peakHour']['hour'];
          peakHour = rawHour != null ? "$rawHour:00" : "N/A";
        });
      }
    } catch (e) {
      print("Error fetching report: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Timeframe Toggle Buttons
          Center(
            child: ToggleButtons(
              isSelected: [
                selectedTimeframe == 'daily',
                selectedTimeframe == 'weekly',
                selectedTimeframe == 'monthly',
              ],
              onPressed: (index) {
                setState(() {
                  if (index == 0) selectedTimeframe = 'daily';
                  if (index == 1) selectedTimeframe = 'weekly';
                  if (index == 2) selectedTimeframe = 'monthly';
                });
                fetchReportData();
              },
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              selectedColor: Colors.black,
              fillColor: Colors.yellow,
              borderRadius: BorderRadius.circular(10),
              borderColor: Colors.yellow,
              selectedBorderColor: Colors.yellow,
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Daily", style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Weekly", style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Monthly", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 2. Report Data Display
          isLoading
              ? const Expanded(child: ServeoSpinner())
              : Expanded(
                  child: ListView(
                    children: [
                      buildReportCard("Total Sales", "₹$totalSales", Icons.currency_rupee, Colors.green, isDark),
                      const SizedBox(height: 16),
                      buildReportCard("Most Sold Product", mostSoldProduct, Icons.fastfood, const Color(0xFFD97706), isDark),
                      const SizedBox(height: 16),
                      buildReportCard("Peak Hour", peakHour, Icons.access_time, Colors.blue, isDark),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  // Helper widget to make the stats look good
  Widget buildReportCard(String title, String value, IconData icon, Color color, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final valueColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: titleColor, fontSize: 15)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}