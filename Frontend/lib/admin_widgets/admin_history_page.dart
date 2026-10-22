import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatelessWidget{
  const HistoryPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    final historyOrders = context.watch<AdminOrderProvider>().historyOrders;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyOrders.length,
      itemBuilder: (context, index) {
        final order = historyOrders[index];
        return Card(
          color: cardBg,
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(
              "Order #${order.id.length >= 4 ? order.id.substring(order.id.length - 4) : order.id}",
              style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${order.uid} • ₹${order.totalAmount}", style: TextStyle(color: secondaryTextColor)),
            trailing: Text(order.orderDate.toString(), style: TextStyle(color: isDark ? Colors.grey : const Color(0xFF9CA3AF))),
          ),
        );
      },
    );
  }
}