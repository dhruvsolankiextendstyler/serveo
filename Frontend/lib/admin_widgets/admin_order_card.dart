import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';
import 'admin_order_details.dart';

class AdminOrderCard extends StatelessWidget {
  final AdminOrder order;
  const AdminOrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    if (order.status == 'Processing' || order.status == 'Pending' || order.status == 'Accepted') statusColor = Colors.orange;
    if (order.status == 'Preparing') statusColor = Colors.blue;
    if (order.status == 'Completed' || order.status == 'Ready' || order.status == 'Collected') statusColor = Colors.green;
    if (order.status == 'Payment Rejected' || order.status == 'Cancelled') statusColor = Colors.redAccent;

    // Highlight orders awaiting UPI verification with Amber emphasis
    if (order.isUpi && order.isAwaitingVerification) {
      statusColor = Colors.amber;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    final shortOrderId = order.id.length >= 4
        ? order.id.substring(order.id.length - 4)
        : order.id;

    return GestureDetector(
      onTap: () {
        final provider = context.read<AdminOrderProvider>();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: provider,
              child: AdminOrderDetailsPage(order: order),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border(
            left: BorderSide(
              color: statusColor,
              width: order.isAwaitingVerification ? 6 : 5,
            ),
          ),
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
                    Row(
                      children: [
                        Text(
                          "Order #$shortOrderId",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        if (order.isAwaitingVerification) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              "VERIFY UPI",
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (order.formattedPlacementTime.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: secondaryTextColor),
                          const SizedBox(width: 4),
                          Text(
                            order.formattedPlacementTime,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
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
                  child: Text(
                    order.isAwaitingVerification
                        ? "AWAITING VERIFICATION"
                        : order.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Customer Details snippet
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: secondaryTextColor),
                const SizedBox(width: 4),
                Text(
                  order.customerName,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (order.customerPhone.isNotEmpty && order.customerPhone != 'N/A') ...[
                  const SizedBox(width: 8),
                  Text("•", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                  const SizedBox(width: 8),
                  Icon(Icons.phone_outlined, size: 13, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    order.customerPhone,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            Divider(color: dividerColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${order.orderItems.length} Items • ₹${order.totalAmount}",
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
                ),
                _buildMethodBadge(order, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodBadge(AdminOrder order, bool isDark) {
    if (order.isUpi) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: order.isAwaitingVerification
              ? Colors.amber.withValues(alpha: 0.15)
              : Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 13,
              color: order.isAwaitingVerification ? const Color(0xFFD97706) : Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              order.isAwaitingVerification ? "UPI (Unverified)" : "UPI (Paid)",
              style: TextStyle(
                color: order.isAwaitingVerification ? const Color(0xFFD97706) : Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (order.isCod) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 13, color: Colors.blue),
            SizedBox(width: 4),
            Text(
              "COD",
              style: TextStyle(
                color: Colors.blue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          "Card (Demo)",
          style: TextStyle(
            color: Colors.purple,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }
}