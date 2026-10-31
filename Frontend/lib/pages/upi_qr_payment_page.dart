import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
import '../utils/payment_config.dart';
import '../utils/theme_provider.dart';
import '../widgets/serveo_glass_container.dart';
import 'order_history_page.dart';
import 'order_tracking_page.dart';

class UpiQrPaymentPage extends StatefulWidget {
  final Order order;

  const UpiQrPaymentPage({super.key, required this.order});

  @override
  State<UpiQrPaymentPage> createState() => _UpiQrPaymentPageState();
}

class _UpiQrPaymentPageState extends State<UpiQrPaymentPage> {
  bool _isClaiming = false;
  bool _claimSubmitted = false;

  Future<void> _handlePaymentClaimed(OrderProvider orderProvider) async {
    if (_isClaiming || _claimSubmitted) return;

    setState(() => _isClaiming = true);

    try {
      final success = await orderProvider.claimPayment(widget.order.id);
      if (!mounted) return;

      if (success) {
        setState(() {
          _claimSubmitted = true;
          _isClaiming = false;
        });

        // Show explicit "Awaiting Verification" dialog (NOT a fake payment success)
        _showClaimSubmittedDialog(context, orderProvider);
      } else {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to submit payment claim. Please check your network and try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClaiming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showClaimSubmittedDialog(BuildContext context, OrderProvider orderProvider) {
    showGlassDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isDark = dialogCtx.watch<ThemeProvider>().isDark;
        final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 54),
              ),
              const SizedBox(height: 18),
              Text(
                widget.order.isPaymentRejected
                    ? "Payment Re-verification Submitted"
                    : "Payment Claim Submitted",
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
                child: Text(
                  widget.order.isPaymentRejected
                      ? "AWAITING ADMIN RE-VERIFICATION"
                      : "AWAITING ADMIN VERIFICATION",
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "We have notified the store admin that you have paid for Order #${widget.order.id.length >= 4 ? widget.order.id.substring(widget.order.id.length - 4) : widget.order.id}.\n\nThe kitchen will begin preparing your food as soon as payment is verified.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChangeNotifierProvider.value(
                          value: orderProvider,
                          child: OrderTrackingPage(
                            orderId: widget.order.id,
                            initialOrder: widget.order,
                          ),
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
                    "Track Order",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context); // Back to payment/cart
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

  void _copyUpiId() {
    if (PaymentConfig.upiId.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: PaymentConfig.upiId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("UPI ID copied to clipboard"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    final shortOrderId = widget.order.id.length >= 4
        ? widget.order.id.substring(widget.order.id.length - 4)
        : widget.order.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "UPI Payment (Manual)",
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Rejection Alert Banner (if resubmitting)
                    if (widget.order.isPaymentRejected) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  "Previous Verification Rejected",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.order.paymentRejectionReason != null &&
                                widget.order.paymentRejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Reason: ${widget.order.paymentRejectionReason}",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              "Please ensure the exact amount of ₹${widget.order.totalAmount} has been transferred to the merchant UPI ID below, then tap 'Submit Verification Again'.",
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Notice Banner
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
                                  "Manual Payment Verification",
                                  style: TextStyle(
                                    color: Color(0xFFD97706),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Scan the QR code below using your GPay or UPI app, transfer the exact amount, and tap 'I've completed the payment'. The admin will verify the transfer manually.",
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

                    // Order Number & Amount Card
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
                                "Order #$shortOrderId",
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.order.orderItems.length} items • Manual UPI",
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Payable Amount",
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₹${widget.order.totalAmount}",
                                style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Prominent QR Code Display / Configuration Fallback
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          if (PaymentConfig.isConfigured) ...[
                            // Configured QR Code view
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final qrUrl = PaymentConfig.getQrUrlForOrder(
                                    orderId: widget.order.id,
                                    amount: widget.order.totalAmount,
                                  );
                                  if (qrUrl != null) {
                                    return Image.network(
                                      qrUrl,
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        PaymentConfig.qrAssetPath,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => _buildUnconfiguredQrFallback(isDark),
                                      ),
                                    );
                                  }
                                  return Image.asset(
                                    PaymentConfig.qrAssetPath,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _buildUnconfiguredQrFallback(isDark),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (PaymentConfig.recipientName.isNotEmpty) ...[
                              Text(
                                PaymentConfig.recipientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (PaymentConfig.upiId.isNotEmpty) ...[
                              InkWell(
                                onTap: _copyUpiId,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        PaymentConfig.upiId,
                                        style: TextStyle(
                                          color: isDark ? Colors.yellow : const Color(0xFFD97706),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 15,
                                        color: isDark ? Colors.yellow : const Color(0xFFD97706),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // Unconfigured QR Code message
                            _buildUnconfiguredQrFallback(isDark),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Clear Instructions
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
                          Text(
                            "PAYMENT INSTRUCTIONS",
                            style: TextStyle(
                              color: isDark ? Colors.yellow : const Color(0xFFD97706),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionStep("1", "Open Google Pay, PhonePe, Paytm, or any UPI app.", isDark),
                          const SizedBox(height: 10),
                          _buildInstructionStep("2", "Scan the QR code or enter the merchant UPI ID.", isDark),
                          const SizedBox(height: 10),
                          _buildInstructionStep("3", "Transfer exact payable amount: ₹${widget.order.totalAmount}.", isDark),
                          const SizedBox(height: 10),
                          _buildInstructionStep("4", "Tap 'I've completed the payment' below so the admin can verify.", isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions
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
                      onPressed: (_isClaiming || _claimSubmitted)
                          ? null
                          : () => _handlePaymentClaimed(orderProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isClaiming
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
                                  "Submitting Claim...",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.order.isPaymentRejected ? Icons.replay_rounded : Icons.check_circle_outline,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.order.isPaymentRejected
                                      ? "Submit Verification Again"
                                      : "I've completed the payment",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isClaiming
                        ? null
                        : () {
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
                    child: Text(
                      "Pay Later / Track in Orders",
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

  Widget _buildUnconfiguredQrFallback(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 72,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                "Merchant UPI QR Not Configured",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "To display your personal/merchant GPay QR code during client demonstrations, configure PaymentConfig in 'lib/utils/payment_config.dart'.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String stepNumber, String instruction, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Colors.yellow.withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.yellow : const Color(0xFFD97706),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            instruction,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
