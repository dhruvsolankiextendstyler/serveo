import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:provider/provider.dart';
import '../admin_utils/admin_order.dart';

class AdminOrderDetailsPage extends StatefulWidget {
  final AdminOrder order;

  const AdminOrderDetailsPage({super.key, required this.order});

  @override
  State<AdminOrderDetailsPage> createState() => _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends State<AdminOrderDetailsPage> {
  bool _isProcessingAction = false;

  Future<void> _handleVerifyPayment(bool confirm) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);
    final provider = context.read<AdminOrderProvider>();

    try {
      final success = await provider.verifyPayment(widget.order.id, confirm);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirm
                  ? "Payment confirmed! Order moved to kitchen preparation."
                  : "Payment claim rejected. Order kept out of preparation.",
            ),
            backgroundColor: confirm ? Colors.green : Colors.redAccent,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to process payment verification. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleUpdateStatus(String newStatus) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);
    final provider = context.read<AdminOrderProvider>();

    try {
      await provider.updateStatus(widget.order.id, newStatus);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to get reactive updates for this order
    final orderProvider = context.watch<AdminOrderProvider>();
    final currentOrder = orderProvider.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final dividerColor = isDark ? Colors.white24 : const Color(0xFFE5E7EB);

    final shortOrderId = currentOrder.id.length >= 6
        ? currentOrder.id.substring(currentOrder.id.length - 6)
        : currentOrder.id;

    Color statusBadgeColor = Colors.grey;
    if (currentOrder.status == 'Processing' || currentOrder.status == 'Pending' || currentOrder.status == 'Accepted') statusBadgeColor = Colors.orange;
    if (currentOrder.status == 'Preparing') statusBadgeColor = Colors.blue;
    if (currentOrder.status == 'Completed' || currentOrder.status == 'Ready' || currentOrder.status == 'Collected') statusBadgeColor = Colors.green;
    if (currentOrder.status == 'Payment Rejected' || currentOrder.status == 'Cancelled') statusBadgeColor = Colors.redAccent;
    if (currentOrder.isUpi && currentOrder.isAwaitingVerification) statusBadgeColor = Colors.amber;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Order Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Order Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Order #$shortOrderId",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "ID: ${currentOrder.id}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusBadgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusBadgeColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  currentOrder.status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusBadgeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: secondaryTextColor),
                              const SizedBox(width: 6),
                              Text(
                                "Placed: ${currentOrder.formattedPlacementTime}",
                                style: TextStyle(color: secondaryTextColor, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Customer Information Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_pin_rounded, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "CUSTOMER INFORMATION",
                                style: TextStyle(
                                  color: isDark ? Colors.yellow : const Color(0xFFD97706),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.person_outline,
                            label: "Full Name",
                            value: currentOrder.customerName,
                            textColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.phone_outlined,
                            label: "Contact Number",
                            value: currentOrder.customerPhone,
                            textColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          if (currentOrder.customerEmail.isNotEmpty && currentOrder.customerEmail != 'N/A') ...[
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              icon: Icons.email_outlined,
                              label: "Email Address",
                              value: currentOrder.customerEmail,
                              textColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Payment Information Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "PAYMENT INFORMATION",
                                style: TextStyle(
                                  color: isDark ? Colors.yellow : const Color(0xFFD97706),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                            icon: currentOrder.isUpi ? Icons.qr_code_2_rounded : Icons.payments_outlined,
                            label: "Payment Method",
                            value: currentOrder.isUpi
                                ? "UPI (GPay / PhonePe / QR)"
                                : (currentOrder.isCod ? "Cash on Delivery (COD)" : "Card (Demo)"),
                            textColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.verified_user_outlined,
                            label: "Payment Status",
                            value: currentOrder.paymentStatus,
                            badgeColor: currentOrder.isAwaitingVerification
                                ? Colors.amber
                                : (currentOrder.isVerified ? Colors.green : Colors.blue),
                            textColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          if (currentOrder.isUpi && currentOrder.paymentClaimedAt != null) ...[
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              icon: Icons.access_time,
                              label: "Claimed At",
                              value: currentOrder.formattedClaimTime,
                              textColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                            ),
                          ],
                          if (currentOrder.paymentVerifiedAt != null) ...[
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              icon: Icons.check_circle_outline,
                              label: "Verified At",
                              value: currentOrder.formattedVerifiedTime,
                              textColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                            ),
                          ],
                          if (currentOrder.verifiedBy != null && currentOrder.verifiedBy!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              icon: Icons.admin_panel_settings_outlined,
                              label: "Verified By",
                              value: currentOrder.verifiedBy!,
                              textColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Order Items Table
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "ORDERED ITEMS (${currentOrder.orderItems.length})",
                                style: TextStyle(
                                  color: isDark ? Colors.yellow : const Color(0xFFD97706),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...currentOrder.orderItems.map((item) {
                            final itemName = item['itemName']?.toString() ?? 'Item';
                            final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                            final price = int.tryParse(item['itemPrice']?.toString() ?? '0') ?? 0;
                            final lineTotal = quantity * price;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName,
                                          style: TextStyle(
                                            color: primaryTextColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$quantity × ₹$price",
                                          style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "₹$lineTotal",
                                    style: const TextStyle(
                                      color: Color(0xFFD97706),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Divider(color: dividerColor, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Subtotal",
                                style: TextStyle(color: secondaryTextColor, fontSize: 14),
                              ),
                              Text(
                                "₹${currentOrder.totalAmount}",
                                style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Payable Amount",
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "₹${currentOrder.totalAmount}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // 5. Control Panel / Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _buildActionButtons(currentOrder, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? badgeColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: badgeColor != null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(AdminOrder order, bool isDark) {
    if (_isProcessingAction) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.yellow),
        ),
      );
    }

    // Awaiting UPI verification: Show Confirm and Reject actions
    if (order.isUpi && order.isAwaitingVerification) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _handleVerifyPayment(true),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                "Confirm Payment Received",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _handleVerifyPayment(false),
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
              label: const Text(
                "Payment Not Received / Reject Claim",
                style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    // Standard Preparation workflow for COD or verified UPI
    if (order.status == 'Processing' || order.status == 'Pending' || order.status == 'Accepted') {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _handleUpdateStatus("Preparing"),
          child: const Text(
            "ACCEPT & COOK",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (order.status == 'Preparing') {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _handleUpdateStatus("Completed"),
          child: const Text(
            "MARK AS READY",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (order.status == 'Completed' || order.status == 'Ready') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text(
              "Order Ready for Pickup",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    } else if (order.status == 'Collected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "Order Collected",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      );
    } else if (order.status == 'Payment Rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Payment Claim Rejected",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}