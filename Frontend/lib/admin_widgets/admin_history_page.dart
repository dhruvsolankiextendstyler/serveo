import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';
import 'admin_order_details.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedFilter = 'All';

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Collected':
      case 'Completed':
        return const Color(0xFF10B981); // Emerald green
      case 'Ready':
        return const Color(0xFF3B82F6); // Blue
      case 'Cancelled':
      case 'Payment Rejected':
        return const Color(0xFFEF4444); // Red
      case 'Preparing':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<AdminOrderProvider>();
    final allHistoryOrders = orderProvider.historyOrders;

    final filteredOrders = allHistoryOrders.where((order) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Collected') return order.status == 'Collected';
      if (_selectedFilter == 'Completed') return order.status == 'Completed';
      if (_selectedFilter == 'Cancelled') {
        return order.status == 'Cancelled' || order.status == 'Payment Rejected';
      }
      return order.status == _selectedFilter;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final mutedTextColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFF3F4F6);

    return RefreshIndicator(
      onRefresh: () => orderProvider.fetchOrders(),
      child: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', allHistoryOrders.length, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Collected',
                    allHistoryOrders.where((o) => o.status == 'Collected').length,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed',
                    allHistoryOrders.where((o) => o.status == 'Completed').length,
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Cancelled',
                    allHistoryOrders.where((o) => o.status == 'Cancelled' || o.status == 'Payment Rejected').length,
                    isDark,
                  ),
                ],
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildHistoryOrderCard(
                        order: order,
                        isDark: isDark,
                        cardBg: cardBg,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        mutedTextColor: mutedTextColor,
                        borderColor: borderColor,
                        dividerColor: dividerColor,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, bool isDark) {
    final isSelected = _selectedFilter == label;
    final activeColor = isDark ? Colors.yellow : const Color(0xFFD97706);

    return FilterChip(
      label: Text(
        count > 0 ? "$label ($count)" : label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
      checkmarkColor: isDark ? Colors.black : Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
        ),
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = label);
      },
    );
  }

  Widget _buildHistoryOrderCard({
    required AdminOrder order,
    required bool isDark,
    required Color cardBg,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color mutedTextColor,
    required Color borderColor,
    required Color dividerColor,
  }) {
    final items = order.parsedOrderItems;
    final statusColor = _getStatusColor(order.status);
    final hasCustomer = order.customerName.isNotEmpty &&
        order.customerName != 'Customer' &&
        order.customerName != 'N/A';

    final shortOrderId = order.id.length >= 6
        ? order.id.substring(order.id.length - 6)
        : order.id;

    // Payment display text
    String paymentDisplay = order.paymentMethod;
    if (order.isUpi) {
      paymentDisplay = "UPI (${order.paymentStatus})";
    } else if (order.isCod) {
      paymentDisplay = "COD";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Order Header: ID + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        "Order #$shortOrderId",
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Customer Name (if available)
                if (hasCustomer) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: secondaryTextColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.customerName,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                Divider(color: dividerColor, height: 1),
                const SizedBox(height: 10),

                // 3. Concise List of Food Items Ordered
                if (items.isNotEmpty) ...[
                  ...items.map((item) {
                    final name = item['itemName'] as String;
                    final qty = item['quantity'] as int;
                    final price = item['itemPrice'] as int;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "- ",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "$name × $qty",
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 14,
                                height: 1.3,
                              ),
                              softWrap: true,
                            ),
                          ),
                          if (price > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              "₹${price * qty}",
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Text(
                    "No items detailed",
                    style: TextStyle(color: mutedTextColor, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: 12),
                Divider(color: dividerColor, height: 1),
                const SizedBox(height: 10),

                // 4. Summary: Total + Placed Time + Payment Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placed Time & Payment
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Placed: ${order.formattedDateTimeKolkata}",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Payment: $paymentDisplay",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Order Total
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Total: ₹${order.totalAmount}",
                          style: TextStyle(
                            color: isDark ? Colors.yellow : const Color(0xFFD97706),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "No Order History Found",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == 'All'
                  ? "Completed, collected, and cancelled orders will appear here."
                  : "No orders match the '$_selectedFilter' filter.",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}