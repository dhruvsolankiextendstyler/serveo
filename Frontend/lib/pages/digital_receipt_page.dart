import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:screen_protector/screen_protector.dart';
import '../utils/api_config.dart';
import '../utils/order_provider.dart';

class DigitalReceiptPage extends StatefulWidget {
  final String orderId;
  final List<dynamic> items;
  final Order? order;
  final bool initialShowPickupToken;

  const DigitalReceiptPage({
    super.key,
    required this.orderId,
    required this.items,
    this.order,
    this.initialShowPickupToken = false,
  });

  @override
  State<DigitalReceiptPage> createState() => _DigitalReceiptPageState();
}

class _DigitalReceiptPageState extends State<DigitalReceiptPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _timeLeft = 120; // 2 Minutes validity for pickup token
  bool _isCollected = false;
  Timer? _timer;
  late bool _showPickupToken;

  @override
  void initState() {
    super.initState();
    _showPickupToken = widget.initialShowPickupToken;
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (_showPickupToken) {
      _controller.repeat();
      _enableSecureMode();
      _startTimer();
    }
  }

  Future<void> _markAsCollected() async {
    if (_isCollected) return;
    _isCollected = true;

    try {
      final response = await patch(
        Uri.parse("${ApiConfig.baseUrl}/order/updatecollected"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": widget.orderId}),
      );

      if (response.statusCode == 200) {
        debugPrint("Order marked as collected successfully.");
      }
    } catch (e) {
      debugPrint("Error marking order as collected: $e");
    }
  }

  Future<void> _enableSecureMode() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {}
  }

  Future<void> _disableSecureMode() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() async {
    await _markAsCollected();
    if (mounted) Navigator.pop(context);
  }

  void _togglePickupToken(bool show) {
    setState(() {
      _showPickupToken = show;
      if (show) {
        _controller.repeat();
        _enableSecureMode();
        _startTimer();
      } else {
        _controller.stop();
        _disableSecureMode();
        _timer?.cancel();
      }
    });
  }

  void _copyReceiptToClipboard(int total) {
    final buffer = StringBuffer();
    buffer.writeln("=== SERVEO DIGITAL RECEIPT ===");
    buffer.writeln("Order ID: #${widget.orderId}");
    buffer.writeln("Date: ${widget.order?.orderDate ?? 'Recent'}");
    buffer.writeln("Payment: ${widget.order?.paymentMethod ?? 'UPI'} - ${widget.order?.paymentStatus ?? 'Pending'}");
    buffer.writeln("-------------------------------");
    for (final item in widget.items) {
      final name = item['itemName'] ?? item['name'] ?? 'Item';
      final qty = item['quantity'] ?? 1;
      final price = item['itemPrice'] ?? 0;
      buffer.writeln("$name x $qty = ₹${price * qty}");
      if (item['selectedCustomizations'] is List) {
        for (final c in item['selectedCustomizations']) {
          buffer.writeln("  + ${c['optionName']} (₹${c['price']})");
        }
      }
    }
    buffer.writeln("-------------------------------");
    buffer.writeln("Total: ₹$total");
    buffer.writeln("===============================");

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Receipt copied to clipboard!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    if (_showPickupToken) {
      _markAsCollected();
    }
    _disableSecureMode();
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPickupToken) {
      return _buildPickupTokenView();
    }
    return _buildItemizedReceiptView();
  }

  // --- 1. Itemized Digital Receipt View ---
  Widget _buildItemizedReceiptView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    final shortOrderId = widget.orderId.length >= 4
        ? widget.orderId.substring(widget.orderId.length - 4)
        : widget.orderId;

    // Calculate subtotal from items if order.totalAmount is unavailable
    int calculatedTotal = 0;
    for (final item in widget.items) {
      final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final price = int.tryParse(item['itemPrice']?.toString() ?? '0') ?? 0;
      calculatedTotal += qty * price;
    }
    final int finalTotal = widget.order?.totalAmount ?? calculatedTotal;

    // Determine payment badge info
    String paymentBadgeText = "UNPAID • PENDING";
    Color paymentBadgeColor = Colors.orange;

    final pMethod = (widget.order?.paymentMethod ?? 'UPI').toUpperCase();
    final pStatus = widget.order?.paymentStatus ?? 'Pending';

    if (pMethod == 'COD') {
      paymentBadgeText = "CASH ON PICKUP (UNPAID)";
      paymentBadgeColor = Colors.teal;
    } else if (pStatus == 'Verified') {
      paymentBadgeText = "PAID (UPI VERIFIED)";
      paymentBadgeColor = Colors.green;
    } else if (pStatus == 'Awaiting Verification') {
      paymentBadgeText = "AWAITING VERIFICATION";
      paymentBadgeColor = const Color(0xFFD97706);
    } else if (pStatus == 'Rejected') {
      paymentBadgeText = "PAYMENT REJECTED";
      paymentBadgeColor = Colors.redAccent;
    } else if (pMethod == 'CARD') {
      paymentBadgeText = "PAID (CARD DEMO)";
      paymentBadgeColor = Colors.purple;
    }

    final isOrderReadyOrCompleted = widget.order?.status == 'Ready' ||
        widget.order?.status == 'Completed' ||
        widget.order?.status == 'Collected';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Digital Receipt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: "Copy / Share Receipt",
            onPressed: () => _copyReceiptToClipboard(finalTotal),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Receipt Container
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Receipt Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.restaurant_rounded, color: Color(0xFFD97706), size: 36),
                          const SizedBox(height: 8),
                          Text(
                            "SERVEO DINING",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Campus Food Ordering & Express Pickup",
                            style: TextStyle(fontSize: 12, color: secondaryTextColor),
                          ),
                          const SizedBox(height: 12),
                          // Payment Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: paymentBadgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: paymentBadgeColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              paymentBadgeText,
                              style: TextStyle(
                                color: paymentBadgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Order Meta Details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildReceiptRow("Order Number", "#$shortOrderId", primaryTextColor, isBold: true),
                          const SizedBox(height: 8),
                          _buildReceiptRow("Full Order ID", widget.orderId, secondaryTextColor, isMonospace: true),
                          const SizedBox(height: 8),
                          _buildReceiptRow("Date & Time", widget.order?.orderDate ?? "Recent", secondaryTextColor),
                          const SizedBox(height: 8),
                          _buildReceiptRow("Payment Method", pMethod, secondaryTextColor),
                          const Divider(height: 24),

                          // Items Header
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "ITEMIZED BREAKDOWN",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Items List
                          ...widget.items.map((item) {
                            final name = item['itemName'] ?? item['name'] ?? 'Item';
                            final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                            final price = int.tryParse(item['itemPrice']?.toString() ?? '0') ?? 0;
                            final lineTotal = qty * price;
                            final rawCusts = item['selectedCustomizations'];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "$name × $qty",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "₹$lineTotal",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rawCusts is List && rawCusts.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: rawCusts.map<Widget>((c) {
                                        final opt = c['optionName']?.toString() ?? '';
                                        final cPrice = int.tryParse(c['price']?.toString() ?? '0') ?? 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            cPrice > 0 ? "$opt (+₹$cPrice)" : opt,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: secondaryTextColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),

                          const Divider(height: 24),

                          // Financial Totals
                          _buildReceiptRow("Subtotal", "₹$finalTotal", secondaryTextColor),
                          const SizedBox(height: 6),
                          _buildReceiptRow("Taxes & Service Fees", "₹0 (Included)", secondaryTextColor),
                          const Divider(height: 24),
                          _buildReceiptRow(
                            "Grand Total",
                            "₹$finalTotal",
                            const Color(0xFFD97706),
                            isBold: true,
                            fontSize: 18,
                          ),
                        ],
                      ),
                    ),

                    // Receipt Footer Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF9FAFB),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Thank you for dining with Serveo!",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Please retain this receipt for your records or counter collection.",
                            style: TextStyle(fontSize: 11, color: secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Switch to Pickup Token Button (if ready or available)
              if (isOrderReadyOrCompleted) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _togglePickupToken(true),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
                    label: const Text(
                      "Open Animated Pickup Token",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Copy Receipt Action Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _copyReceiptToClipboard(finalTotal),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text("Copy Text Summary"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    bool isMonospace = false,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  // --- 2. Live Pickup Token Animated View (Counter Staff Proof-of-Life) ---
  Widget _buildPickupTokenView() {
    String minutes = (_timeLeft ~/ 60).toString().padLeft(2, '0');
    String seconds = (_timeLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.yellowAccent[700],
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                "LIVE PICKUP TOKEN",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.black),
              ),
              const SizedBox(height: 30),

              // Rotating Burger Spinner
              RotationTransition(
                turns: _controller,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 4),
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.lunch_dining, size: 72, color: Colors.black),
                ),
              ),
              const SizedBox(height: 30),

              const Text("ORDER ID", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
              Text(
                "#${widget.orderId.length >= 4 ? widget.orderId.substring(widget.orderId.length - 4) : widget.orderId}",
                style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w900, height: 1.0, color: Colors.black),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "${widget.items.length} Items • Show to Counter Staff",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),

              const Spacer(),

              // Countdown Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Valid for $minutes:$seconds",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Toggle back to itemized receipt
              TextButton.icon(
                onPressed: () => _togglePickupToken(false),
                icon: const Icon(Icons.receipt_long, color: Colors.black),
                label: const Text(
                  "View Itemized Receipt",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}