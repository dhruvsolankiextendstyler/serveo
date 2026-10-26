import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
import '../utils/theme_provider.dart';
import 'login_page.dart';
import 'order_history_page.dart';

import 'upi_qr_payment_page.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'upi';
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentOptions = const [
    {
      'id': 'upi',
      'title': 'UPI (Google Pay, PhonePe, Paytm)',
      'subtitle': 'Simulated instant UPI checkout demo',
      'icon': Icons.qr_code_2_rounded,
    },
    {
      'id': 'cash',
      'title': 'Pay at Counter / Cash',
      'subtitle': 'Pay with cash upon picking up your order',
      'icon': Icons.payments_outlined,
    },
    {
      'id': 'card',
      'title': 'Credit / Debit Card (Mock)',
      'subtitle': 'Simulated card transaction demo',
      'icon': Icons.credit_card_outlined,
    },
  ];

  Future<void> _handlePayment(OrderProvider orderProvider) async {
    if (_isProcessing) return;

    if (orderProvider.orderItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your cart is empty")),
      );
      Navigator.pop(context);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please sign in to complete your order"),
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: "Sign In",
            textColor: Colors.yellow,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            },
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (_selectedMethod == 'upi') {
        // Option A: Online / UPI Payment flow
        // 1. Create order on backend with paymentMethod = "UPI"
        final createdOrder = await orderProvider.placeOrder(paymentMethod: "UPI");

        if (!mounted) return;

        if (createdOrder != null) {
          // Navigate to dedicated UPI QR payment screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: orderProvider,
                child: UpiQrPaymentPage(order: createdOrder),
              ),
            ),
          );
          return;
        } else {
          final errorMsg = orderProvider.lastOrderError ??
              "Failed to initiate UPI payment. Please try again.";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: (errorMsg.contains("sign in") || errorMsg.contains("Authentication"))
                  ? SnackBarAction(
                      label: "Sign In",
                      textColor: Colors.yellow,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LoginPage()),
                        );
                      },
                    )
                  : null,
            ),
          );
        }
      } else if (_selectedMethod == 'cash') {
        // Option B: Cash on Delivery / Pay at Counter flow
        final total = orderProvider.getTotal();
        final createdOrder = await orderProvider.placeOrder(paymentMethod: "COD");

        if (!mounted) return;

        if (createdOrder == null && orderProvider.lastOrderError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(orderProvider.lastOrderError!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Show COD Order Placed confirmation dialog (No QR code)
        final shortId = createdOrder != null && createdOrder.id.length >= 4
            ? createdOrder.id.substring(createdOrder.id.length - 4)
            : "";

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final isDark = dialogContext.watch<ThemeProvider>().isDark;
            final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Order Placed (Cash on Delivery)",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      "PAY CASH AT COUNTER",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    shortId.isNotEmpty
                        ? "Your order #$shortId has been sent to the kitchen!\nPlease pay ₹$total in cash upon collecting your order."
                        : "Your order has been sent to the kitchen!\nPlease pay ₹$total in cash upon collecting your order.",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider.value(
                              value: orderProvider,
                              child: const OrderHistoryPage(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "View Order History",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Back to Menu",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // Preserved Option: Simulated Card Transaction Demo
        await Future.delayed(const Duration(milliseconds: 1200));
        await orderProvider.placeOrder(paymentMethod: "Card");

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final isDark = dialogContext.watch<ThemeProvider>().isDark;
            final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Demo Payment Successful",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      "SIMULATED PAYMENT COMPLETED",
                      style: TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "This was a product demonstration. No money was charged.\nYour demo order has been sent to the kitchen!",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider.value(
                              value: orderProvider,
                              child: const OrderHistoryPage(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "View Order History",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Back to Menu",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting order: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;
    final total = orderProvider.getTotal();

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Choose Payment Method",
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Visible Demo Notice Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Demo Payment Experience",
                                  style: TextStyle(
                                    color: Color(0xFFD97706),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "This is a simulated payment screen for shop demonstrations. No real transactions or sensitive credentials are required.",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔹 Order Total Summary Card
                    Container(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Amount",
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${orderProvider.orderItems.length} items in tray",
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "₹$total",
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🔹 Payment Options Header
                    Text(
                      "PAYMENT OPTIONS",
                      style: TextStyle(
                        color: isDark ? Colors.yellow : const Color(0xFFD97706),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 🔹 Mock Payment Options List
                    ..._paymentOptions.map((opt) {
                      final isSelected = _selectedMethod == opt['id'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isProcessing
                              ? null
                              : () => setState(() => _selectedMethod = opt['id']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.yellow
                                    : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.yellow.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.yellow.withValues(alpha: 0.2)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : const Color(0xFFF3F4F6)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    opt['icon'] as IconData,
                                    color: isSelected
                                        ? (isDark ? Colors.yellow : const Color(0xFFD97706))
                                        : secondaryTextColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opt['title'] as String,
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        opt['subtitle'] as String,
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected
                                      ? Colors.yellow
                                      : secondaryTextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 🔹 Bottom Actions
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _handlePayment(orderProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Simulating Payment...",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              "Pay Now • ₹$total (Demo)",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: Text(
                      "Back to Cart",
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
