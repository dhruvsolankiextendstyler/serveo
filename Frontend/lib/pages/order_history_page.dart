import 'package:flutter/material.dart';
import 'package:frontend/widgets/breakbite_spinner.dart';
import 'package:provider/provider.dart';
import '../utils/menu_provider.dart';
import '../utils/order_provider.dart';
import 'cart_page.dart';
import 'digital_receipt_page.dart';
import 'order_tracking_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchMyOrders();
    });
  }

  void _handleReorder(BuildContext context, Order order) {
    final menuProvider = context.read<MenuProvider>();
    final orderProvider = context.read<OrderProvider>();

    final result = orderProvider.reorderOrder(order, menuProvider.menuItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF111827);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Reorder Items",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (result.hasAddedItems) ...[
                Text(
                  "Added to your order tray at current catalog prices:",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.addedItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${item.quantityAdded}x ${item.itemName}",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "₹${item.currentPrice * item.quantityAdded}",
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],

              if (result.hasPriceChanges) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Price Updates Notice",
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...result.priceChanges.map((pc) => Text(
                            "• ${pc.itemName}: was ₹${pc.oldPrice}, now ₹${pc.newPrice}",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                              fontSize: 11,
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (result.hasUnavailableItems) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Unavailable Items Skipped",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...result.unavailableItems.map((u) => Text(
                            "• $u",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                              fontSize: 11,
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (!result.hasAddedItems) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "None of the items from this order are currently available in the menu.",
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Keep Browsing"),
                    ),
                  ),
                  if (result.hasAddedItems) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          final orderProvider = context.read<OrderProvider>();
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Review Tray", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.myOrders;
    final isLoading = orderProvider.isLoading;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Orders",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: ServeoSpinner())
          : orders.isEmpty
              ? _buildEmptyState(context, isDark)
              : RefreshIndicator(
                  onRefresh: () => orderProvider.fetchMyOrders(),
                  color: const Color(0xFFD97706),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(context, orders[index], isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final iconColor = isDark ? Colors.grey[800] : Colors.grey[400];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood_outlined, size: 80, color: iconColor),
          const SizedBox(height: 20),
          Text(
            "No orders yet!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "You haven't ordered any food yet.\nHungry?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Order Now", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order, bool isDark) {
    Color statusColor;
    switch (order.status) {
      case 'Completed':
      case 'Ready':
        statusColor = Colors.green;
        break;
      case 'Processing':
      case 'Pending':
      case 'Accepted':
      case 'Pending Verification':
        statusColor = Colors.orange;
        break;
      case 'Preparing':
        statusColor = Colors.blue;
        break;
      case 'Collected':
        statusColor = Colors.green;
        break;
      case 'Payment Rejected':
      case 'Cancelled':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = Colors.blue;
    }

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final dividerColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);

    final shortId = order.id.length >= 4 ? order.id.substring(order.id.length - 4) : order.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
            children: [
              Text(
                "Order #$shortId",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryTextColor,
                ),
              ),
              _buildStatusChip(order.status, statusColor),
            ],
          ),
          const SizedBox(height: 8),

          // Payment method & payment status badge
          _buildPaymentBadge(order, isDark),
          Divider(color: dividerColor, height: 20),

          // Items summary
          Text(
            order.orderItems.map((item) {
              final name = item['itemName'] ?? item['name'] ?? 'Item';
              final qty = item['quantity'] ?? 1;
              return "$qty× $name";
            }).join(", "),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderDate,
                style: TextStyle(
                  color: isDark ? Colors.grey : const Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
              Text(
                "Total: ₹${order.totalAmount}",
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons: Track Order & Reorder
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderTrackingPage(
                          orderId: order.id,
                          initialOrder: order,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_searching, size: 16),
                  label: const Text(
                    "Track Order",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleReorder(context, order),
                  icon: const Icon(Icons.replay_rounded, size: 16, color: Colors.black),
                  label: const Text(
                    "Reorder",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          if (order.status == 'Completed' || order.status == 'Ready') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DigitalReceiptPage(
                        orderId: order.id,
                        items: order.orderItems,
                      ),
                    ),
                  );

                  if (context.mounted) {
                    context.read<OrderProvider>().fetchMyOrders();
                  }
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.black, size: 18),
                label: const Text(
                  "SHOW PICKUP RECEIPT",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(Order order, bool isDark) {
    String label = "COD (Cash)";
    Color badgeColor = Colors.blue;
    IconData icon = Icons.payments_outlined;

    if (order.paymentMethod.toUpperCase() == 'UPI') {
      icon = Icons.qr_code_2_rounded;
      if (order.paymentStatus == 'Awaiting Verification') {
        label = "UPI • Awaiting Verification";
        badgeColor = const Color(0xFFD97706);
      } else if (order.paymentStatus == 'Verified') {
        label = "UPI • Payment Confirmed";
        badgeColor = Colors.green;
      } else if (order.paymentStatus == 'Rejected') {
        label = "UPI • Payment Not Confirmed";
        badgeColor = Colors.redAccent;
      } else {
        label = "UPI • Payment Pending";
        badgeColor = Colors.orange;
      }
    } else if (order.paymentMethod.toUpperCase() == 'CARD') {
      label = "Card (Demo)";
      badgeColor = Colors.purple;
      icon = Icons.credit_card_outlined;
    } else {
      label = "Cash on Pickup";
      badgeColor = Colors.teal;
      icon = Icons.money_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}