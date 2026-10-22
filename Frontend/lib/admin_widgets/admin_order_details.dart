import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';
import '../admin_utils/admin_order.dart';

class AdminOrderDetailsPage extends StatelessWidget {
  final AdminOrder order;

  const AdminOrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<AdminOrderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final itemBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final dividerColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Order Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order #${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
                Text(
                  order.formattedPlacementTime,
                  style: TextStyle(color: secondaryTextColor, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Item List
            Text("Items Ordered:", style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: order.orderItems.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: itemBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.orderItems[index]['itemName'], style: TextStyle(color: primaryTextColor, fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(
                            "${order.orderItems[index]['quantity'].toString()} x ₹${order.orderItems[index]['itemPrice'].toString()}"
                            , style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                        Text("₹${(order.orderItems[index]['quantity'] * order.orderItems[index]['itemPrice']).toString()}"
                            , style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Total Section
            Divider(color: dividerColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Amount", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                Text("₹${order.totalAmount}", style: const TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),

            // --- ACTION BUTTONS (The Control Panel) ---
            if (order.status == 'Processing') ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () async {
                    await orderProvider.updateStatus(order.id, "Preparing");
                    if(context.mounted) Navigator.of(context).pop();
                  }, // Return new status
                  child: const Text("ACCEPT & COOK", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else if (order.status == 'Preparing') ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    await orderProvider.updateStatus(order.id, "Completed");
                    if(context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text("MARK AS   READY", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}