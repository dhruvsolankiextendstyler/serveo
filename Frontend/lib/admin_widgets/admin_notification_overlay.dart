import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin_utils/admin_order.dart';
import '../admin_utils/admin_order_provider.dart';
import 'admin_order_details.dart';

class AdminNotificationOverlay {
  static OverlayEntry? _currentEntry;
  static String? _currentOrderId;

  static void show({
    required BuildContext context,
    required AdminOrder order,
    required VoidCallback onDismiss,
  }) {
    if (_currentOrderId == order.id && _currentEntry != null) return;
    hide();

    _currentOrderId = order.id;

    // Use root overlay to ensure it floats over any pushed route (e.g. details page, reports)
    final overlayState = Overlay.of(context, rootOverlay: true);

    _currentEntry = OverlayEntry(
      builder: (ctx) => _FloatingAlertWidget(
        order: order,
        onDismiss: () {
          hide();
          onDismiss();
        },
        onReview: () {
          hide();
          final provider = context.read<AdminOrderProvider>();
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (navCtx) => ChangeNotifierProvider.value(
                value: provider,
                child: AdminOrderDetailsPage(order: order),
              ),
            ),
          );
        },
      ),
    );

    overlayState.insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentOrderId = null;
  }

  static bool get isShowing => _currentEntry != null;
}

class _FloatingAlertWidget extends StatefulWidget {
  final AdminOrder order;
  final VoidCallback onDismiss;
  final VoidCallback onReview;

  const _FloatingAlertWidget({
    required this.order,
    required this.onDismiss,
    required this.onReview,
  });

  @override
  State<_FloatingAlertWidget> createState() => _FloatingAlertWidgetState();
}

class _FloatingAlertWidgetState extends State<_FloatingAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _dismissWithAnim() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    final shortOrderId = widget.order.id.length >= 4
        ? widget.order.id.substring(widget.order.id.length - 4)
        : widget.order.id;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.black.withValues(alpha: 0.4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.amber,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Pulsing Bell Icon + Title + Dismiss (X)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFFD97706),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "UPI PAYMENT CLAIMED",
                                style: TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                "Order #$shortOrderId • ₹${widget.order.totalAmount}",
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _dismissWithAnim,
                        icon: const Icon(Icons.close, size: 20),
                        color: secondaryTextColor,
                        tooltip: "Dismiss Alert",
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Customer Details Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.order.customerName,
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.phone_outlined, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              widget.order.customerPhone,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  "Claimed: ${widget.order.formattedClaimTime}",
                                  style: TextStyle(color: secondaryTextColor, fontSize: 11),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "AWAITING VERIFICATION",
                                style: TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons: "Review & Verify" (Primary) + "Dismiss"
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: widget.onReview,
                            icon: const Icon(Icons.verified_outlined, size: 16, color: Colors.black),
                            label: const Text(
                              "Review & Verify Payment",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: _dismissWithAnim,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: secondaryTextColor,
                            side: BorderSide(
                              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Dismiss", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
