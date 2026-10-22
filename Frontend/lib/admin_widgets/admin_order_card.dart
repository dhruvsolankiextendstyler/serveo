import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';
import 'admin_order_details.dart';

class AdminOrderCard extends StatelessWidget{
  final AdminOrder order;
  const AdminOrderCard({super.key, required this.order});
  
  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    if (order.status == 'Processing') statusColor = Colors.orange;
    if (order.status == 'Preparing') statusColor = Colors.blue;
    if (order.status == 'Completed' || order.status == 'Collected') statusColor = Colors.green;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: () {
        final provider = context.read<AdminOrderProvider>();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) =>
            ChangeNotifierProvider.value(
                value: provider,
                child: AdminOrderDetailsPage(order: order)
            )
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border(left: BorderSide(color: statusColor, width: 5)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${order.id.length >= 4 ? order.id.substring(order.id.length - 4) : order.id}",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                    if (order.formattedPlacementTime.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: secondaryTextColor),
                          const SizedBox(width: 4),
                          Text(
                            order.formattedPlacementTime,
                            style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(order.status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            Divider(color: dividerColor),
            Text(
              "${order.orderItems.length} Items • ₹${order.totalAmount}",
              style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}