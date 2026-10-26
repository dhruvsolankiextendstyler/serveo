import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_spinner.dart';
import 'digital_receipt_page.dart';
import 'order_history_page.dart';

class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  final Order? initialOrder;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> with WidgetsBindingObserver {
  Order? _order;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  int _activeRequestId = 0;
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _order = widget.initialOrder;

    // Fetch latest order details immediately
    _fetchLiveStatus();

    // Start polling every 5 seconds if order is not already in a terminal state
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isBackgrounded = true;
      _stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
      _fetchLiveStatus();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startPolling() {
    _stopPolling();
    // Do not poll if the order is already in a terminal state
    if (_order != null && _order!.isTerminal) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isBackgrounded && mounted) {
        _fetchLiveStatus(isSilent: true);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchLiveStatus({bool isSilent = false}) async {
    final requestId = ++_activeRequestId;

    if (!isSilent && _order == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final orderProvider = context.read<OrderProvider>();
      final freshOrder = await orderProvider.trackOrder(widget.orderId);

      // Prevent stale response from overwriting newer state
      if (requestId != _activeRequestId || !mounted) return;

      if (freshOrder != null) {
        setState(() {
          _order = freshOrder;
          _isLoading = false;
          _errorMessage = null;
        });

        // Stop polling if order reached terminal state
        if (freshOrder.isTerminal) {
          _stopPolling();
        }
      } else if (_order == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Unable to load order tracking details. Please try again.";
        });
      }
    } catch (e) {
      if (requestId == _activeRequestId && mounted) {
        setState(() {
          _isLoading = false;
          if (_order == null) {
            _errorMessage = "Connection error. Pull down to refresh.";
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    final shortId = widget.orderId.length >= 4
        ? widget.orderId.substring(widget.orderId.length - 4)
        : widget.orderId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Track Order #$shortId",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh status",
            onPressed: () => _fetchLiveStatus(),
          ),
        ],
      ),
      body: _isLoading && _order == null
          ? const Center(child: ServeoSpinner())
          : _errorMessage != null && _order == null
              ? _buildErrorView(isDark)
              : _order == null
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: () => _fetchLiveStatus(),
                      color: const Color(0xFFD97706),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Order Header Card (ID, Time, Status)
                            _buildOrderHeaderCard(_order!, cardBg, borderColor, primaryTextColor, isDark),
                            const SizedBox(height: 16),

                            // 2. Terminal State Banner (Cancelled / Payment Rejected)
                            if (_order!.isCancelled) ...[
                              _buildTerminalBanner(_order!, isDark),
                              const SizedBox(height: 16),
                            ],

                            // 3. Visual Timeline of Order Progress
                            _buildProgressTimelineCard(_order!, cardBg, borderColor, isDark),
                            const SizedBox(height: 16),

                            // 4. Pickup Receipt CTA (When Ready or Completed)
                            if (_order!.status == 'Ready' || _order!.status == 'Completed') ...[
                              _buildPickupReceiptBanner(_order!),
                              const SizedBox(height: 16),
                            ],

                            // 5. Payment Details Card
                            _buildPaymentSummaryCard(_order!, cardBg, borderColor, isDark),
                            const SizedBox(height: 16),

                            // 6. Ordered Items Card
                            _buildOrderedItemsCard(_order!, cardBg, borderColor, isDark),
                            const SizedBox(height: 24),

                            // 7. Navigation Actions
                            _buildNavigationActions(context, isDark),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildOrderHeaderCard(
    Order order,
    Color cardBg,
    Color borderColor,
    Color primaryTextColor,
    bool isDark,
  ) {
    return Container(
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
              Expanded(
                child: Row(
                  children: [
                    Text(
                      "Order #${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                      tooltip: "Copy Order ID",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: order.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Order ID copied to clipboard"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _buildLivePulseBadge(order.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "${order.orderDate} (IST)",
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivePulseBadge(String status) {
    Color color;
    switch (status) {
      case 'Completed':
      case 'Collected':
      case 'Ready':
        color = Colors.green;
        break;
      case 'Preparing':
        color = Colors.blueAccent;
        break;
      case 'Accepted':
      case 'Processing':
      case 'Pending':
      case 'Pending Verification':
        color = Colors.amber;
        break;
      case 'Cancelled':
      case 'Payment Rejected':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalBanner(Order order, bool isDark) {
    final isRejected = order.status == "Payment Rejected";
    final message = isRejected
        ? "Payment claim was rejected by restaurant admin. Kitchen preparation has been halted. Please check your UPI transaction or pay at the counter."
        : "This order has been cancelled. If you believe this was an error, please speak to counter staff.";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected ? "Payment Rejected" : "Order Cancelled",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimelineCard(
    Order order,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    final isUpi = order.paymentMethod.toUpperCase() == 'UPI';
    final isUpiVerified = order.paymentStatus == 'Verified';
    final isUpiAwaiting = order.paymentStatus == 'Awaiting Verification';
    final isUpiRejected = order.paymentStatus == 'Rejected';

    // Canonical order workflow stages:
    // Placed -> [Payment Verification if UPI] -> Accepted -> Preparing -> Ready -> Collected
    final status = order.status;

    final bool isPlacedDone = true;
    final bool isAcceptedDone = ["Accepted", "Processing", "Preparing", "Ready", "Completed", "Collected"].contains(status);
    final bool isPreparingDone = ["Preparing", "Ready", "Completed", "Collected"].contains(status);
    final bool isReadyDone = ["Ready", "Completed", "Collected"].contains(status);
    final bool isCollectedDone = status == "Collected";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Live Order Progress",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),

          // Stage 1: Order Placed
          _buildTimelineStep(
            title: "Order Placed",
            subtitle: "Received by restaurant order system",
            timestamp: order.orderDate,
            isCompleted: isPlacedDone,
            isActive: status == "Pending" || status == "Processing",
            icon: Icons.receipt_long,
            isDark: isDark,
          ),

          // Stage 2: UPI Payment Verification (Distinct from kitchen prep!)
          if (isUpi) ...[
            _buildTimelineStep(
              title: isUpiVerified
                  ? "UPI Payment Confirmed"
                  : isUpiRejected
                      ? "UPI Claim Not Confirmed"
                      : "Awaiting UPI Verification",
              subtitle: isUpiVerified
                  ? "Admin verified payment reference"
                  : isUpiRejected
                      ? "Admin could not verify UPI transaction"
                      : "Manager is verifying your payment declaration",
              timestamp: order.paymentVerifiedAt != null
                  ? "${order.paymentVerifiedAt!.hour.toString().padLeft(2, '0')}:${order.paymentVerifiedAt!.minute.toString().padLeft(2, '0')}"
                  : null,
              isCompleted: isUpiVerified,
              isActive: isUpiAwaiting,
              isError: isUpiRejected,
              icon: Icons.verified_user_outlined,
              isDark: isDark,
            ),
          ],

          // Stage 3: Order Accepted
          _buildTimelineStep(
            title: "Order Accepted",
            subtitle: "Kitchen acknowledged order details",
            isCompleted: isAcceptedDone,
            isActive: status == "Accepted" || (status == "Processing" && !isUpiAwaiting),
            icon: Icons.thumb_up_alt_outlined,
            isDark: isDark,
          ),

          // Stage 4: Preparing Food
          _buildTimelineStep(
            title: "Preparing Food",
            subtitle: "Chef is cooking fresh ingredients in kitchen",
            isCompleted: isPreparingDone,
            isActive: status == "Preparing",
            icon: Icons.soup_kitchen_outlined,
            isDark: isDark,
          ),

          // Stage 5: Ready for Pickup
          _buildTimelineStep(
            title: "Ready for Pickup",
            subtitle: "Packed and ready at counter. Present pickup receipt.",
            isCompleted: isReadyDone,
            isActive: status == "Ready" || status == "Completed",
            icon: Icons.storefront_outlined,
            isDark: isDark,
          ),

          // Stage 6: Collected
          _buildTimelineStep(
            title: "Collected",
            subtitle: "Order handed over to customer. Enjoy your meal!",
            isCompleted: isCollectedDone,
            isActive: status == "Collected",
            isLast: true,
            icon: Icons.check_circle_outline,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    String? timestamp,
    required bool isCompleted,
    required bool isActive,
    bool isError = false,
    bool isLast = false,
    required IconData icon,
    required bool isDark,
  }) {
    Color stepColor = Colors.grey;
    if (isError) {
      stepColor = Colors.redAccent;
    } else if (isCompleted) {
      stepColor = Colors.green;
    } else if (isActive) {
      stepColor = const Color(0xFFD97706);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator column + line
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: stepColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: stepColor, width: isActive ? 2 : 1.2),
              ),
              child: Center(
                child: Icon(
                  isCompleted ? Icons.check : (isError ? Icons.close : icon),
                  size: 14,
                  color: stepColor,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isCompleted ? Colors.green.withValues(alpha: 0.5) : (isDark ? Colors.white12 : Colors.black12),
              ),
          ],
        ),
        const SizedBox(width: 14),
        // Title & details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (timestamp != null)
                    Text(
                      timestamp,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickupReceiptBanner(Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow, width: 1.5),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.yellow, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Food is Ready at Counter!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Show your digital QR receipt to counter staff to collect your meal.",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DigitalReceiptPage(
                      orderId: order.id,
                      items: order.orderItems,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code, color: Colors.black),
              label: const Text(
                "SHOW PICKUP RECEIPT",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(
    Order order,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    String methodLabel = "Cash on Delivery";
    Color badgeColor = Colors.teal;
    IconData icon = Icons.payments_outlined;

    if (order.paymentMethod.toUpperCase() == 'UPI') {
      icon = Icons.qr_code_2_rounded;
      if (order.paymentStatus == 'Verified') {
        methodLabel = "UPI • Payment Confirmed";
        badgeColor = Colors.green;
      } else if (order.paymentStatus == 'Awaiting Verification') {
        methodLabel = "UPI • Awaiting Verification";
        badgeColor = const Color(0xFFD97706);
      } else if (order.paymentStatus == 'Rejected') {
        methodLabel = "UPI • Payment Rejected";
        badgeColor = Colors.redAccent;
      } else {
        methodLabel = "UPI • Payment Pending";
        badgeColor = Colors.orange;
      }
    } else if (order.paymentMethod.toUpperCase() == 'CARD') {
      methodLabel = "Card (Demo)";
      badgeColor = Colors.purple;
      icon = Icons.credit_card_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Information",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: badgeColor),
                  const SizedBox(width: 8),
                  Text(
                    methodLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                "Total: ₹${order.totalAmount}",
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (order.paymentMethod.toUpperCase() == 'UPI' && order.paymentStatus == 'Awaiting Verification') ...[
            const SizedBox(height: 8),
            Text(
              "Note: Your UPI payment claim has been submitted. Restaurant staff will verify it against the counter account before completing pickup.",
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderedItemsCard(
    Order order,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Items Ordered (${order.orderItems.length})",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.orderItems.length,
            separatorBuilder: (_, __) => Divider(
              color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              height: 16,
            ),
            itemBuilder: (context, index) {
              final item = order.orderItems[index];
              final itemName = item['itemName'] ?? item['name'] ?? 'Item';
              final quantity = item['quantity'] ?? 1;
              final price = item['itemPrice'] ?? 0;
              final lineTotal = price * quantity;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "₹$price × $quantity",
                          style: TextStyle(
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₹$lineTotal",
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
          Divider(color: isDark ? Colors.white24 : const Color(0xFFE5E7EB), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Grand Total",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "₹${order.totalAmount}",
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationActions(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              "Order History",
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1F2937),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              "Back to Menu",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              "Connection Error",
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "Failed to connect to server.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _fetchLiveStatus(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Retry", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Text(
        "Order not found",
        style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
      ),
    );
  }
}
