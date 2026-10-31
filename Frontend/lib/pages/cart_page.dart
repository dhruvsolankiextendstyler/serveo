import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/order_provider.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_bill_details_card.dart';
import '../widgets/breakbite_cart_item_card.dart';
import 'payment_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _couponController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final restProvider = Provider.of<RestaurantProvider?>(context, listen: false);
        final restId = restProvider?.config.id;
        context.read<OrderProvider>().fetchLoyaltyInfo(restaurantId: restId);
      }
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider?>(context);
    final themeProvider = Provider.of<ThemeProvider?>(context);
    final restProvider = Provider.of<RestaurantProvider?>(context);
    final restId = restProvider?.config.id;
    final isDark = themeProvider?.isDark ?? true;

    if (orderProvider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tray")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Unable to load tray state."),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Return to Menu"),
              ),
            ],
          ),
        ),
      );
    }

    final cartItems = orderProvider.orderItems;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Checkout",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: primaryTextColor,
              ),
            ),
            if (cartItems.isNotEmpty)
              Text(
                "${cartItems.length} items in tray",
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
          ],
        ),
      ),
      body: cartItems.isEmpty
          ? _buildEmptyState(context, isDark)
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Dynamic List
                        ...cartItems.map((item) => CartItemCard(item: item)),

                        const SizedBox(height: 16),

                        // Phase 6: Coupon Codes Section
                        _buildCouponSection(context, orderProvider, isDark, restId),

                        const SizedBox(height: 16),

                        // Phase 6: Loyalty Rewards Section
                        _buildLoyaltySection(context, orderProvider, isDark),

                        const SizedBox(height: 20),

                        // Bill card
                        const BillDetailsCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                _buildProceedToPayButton(context, orderProvider, isDark),
              ],
            ),
    );
  }

  Widget _buildCouponSection(
    BuildContext context,
    OrderProvider orderProvider,
    bool isDark,
    String? restId,
  ) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Text(
                "Coupon & Offers",
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (orderProvider.appliedCouponCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Code: ${orderProvider.appliedCouponCode}",
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "Discount applied: -₹${orderProvider.couponDiscount.round()}",
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      _couponController.clear();
                      orderProvider.removeCoupon();
                    },
                    tooltip: "Remove coupon",
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(color: primaryTextColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Enter promo code",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: orderProvider.isApplyingCoupon
                      ? null
                      : () async {
                          final code = _couponController.text.trim();
                          if (code.isNotEmpty) {
                            final success = await orderProvider.applyCoupon(code, restaurantId: restId);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Coupon '$code' applied!"),
                                  backgroundColor: const Color(0xFF16A34A),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: orderProvider.isApplyingCoupon
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Apply", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (orderProvider.couponError != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      orderProvider.couponError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLoyaltySection(
    BuildContext context,
    OrderProvider orderProvider,
    bool isDark,
  ) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    final rewards = orderProvider.availableRewards;
    final points = orderProvider.availableLoyaltyPoints;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Loyalty Rewards",
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text(
                  "$points Points",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rewards.isEmpty) ...[
            Text(
              "Earn points on completed orders to unlock exclusive discounts!",
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
          ] else ...[
            Text(
              "Redeem points for instant discount:",
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text("None"),
                  selected: orderProvider.selectedRewardId == null,
                  onSelected: (selected) {
                    if (selected) orderProvider.selectLoyaltyReward(null);
                  },
                ),
                ...rewards.map((reward) {
                  final rewardId = reward['rewardId'] as String;
                  final title = reward['title'] as String;
                  final ptsReq = (reward['pointsRequired'] ?? 0) as int;
                  final canRedeem = points >= ptsReq;
                  final isSelected = orderProvider.selectedRewardId == rewardId;

                  return ChoiceChip(
                    avatar: isSelected ? const Icon(Icons.check, size: 14) : null,
                    label: Text("$title ($ptsReq pts)"),
                    selected: isSelected,
                    selectedColor: Colors.amber.shade700,
                    disabledColor: Colors.grey.withValues(alpha: 0.2),
                    onSelected: canRedeem
                        ? (selected) {
                            orderProvider.selectLoyaltyReward(selected ? rewardId : null);
                          }
                        : null,
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final iconColor = isDark ? Colors.white24 : Colors.black26;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, key: const Key('empty_tray_icon'), size: 84, color: iconColor),
            const SizedBox(height: 16),
            Text(
              "Your tray is empty!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Browse our delicious menu and add items to your tray.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text("Browse Menu"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProceedToPayButton(
    BuildContext context,
    OrderProvider provider,
    bool isDark,
  ) {
    final grandTotal = provider.getFinalPayableTotal();
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    RestaurantProvider? restProvider;
    try {
      restProvider = Provider.of<RestaurantProvider?>(context);
    } catch (_) {}

    final restConfig = restProvider?.config ?? RestaurantConfig();
    final canOrder = restConfig.canOrder;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canOrder) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: restConfig.isPaused
                      ? const Color(0xFFD97706).withValues(alpha: 0.15)
                      : Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: restConfig.isPaused
                        ? const Color(0xFFD97706).withValues(alpha: 0.4)
                        : Colors.redAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      restConfig.isPaused ? Icons.pause_circle_outline : Icons.schedule,
                      color: restConfig.isPaused ? const Color(0xFFD97706) : Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        restConfig.isPaused
                            ? (restConfig.pauseReason.isNotEmpty ? restConfig.pauseReason : "Ordering temporarily paused.")
                            : "Restaurant is closed (${restConfig.operatingHoursFormatted}).",
                        style: TextStyle(
                          color: restConfig.isPaused ? const Color(0xFFD97706) : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ElevatedButton(
              key: const Key('proceed_to_pay_button'),
              onPressed: canOrder
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangeNotifierProvider.value(
                            value: provider,
                            child: const PaymentPage(),
                          ),
                        ),
                      );
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            restConfig.isPaused
                                ? "Orders are temporarily paused. Please check back shortly."
                                : "Restaurant is closed. Operating hours: ${restConfig.operatingHoursFormatted}",
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: canOrder ? Colors.yellow : Colors.grey.shade400,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    canOrder ? "Proceed to Pay • ₹$grandTotal" : "Ordering Currently Unavailable",
                    style: TextStyle(
                      color: canOrder ? Colors.black : Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (canOrder) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
