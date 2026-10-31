import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/api_config.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';

class CustomerReferralPage extends StatefulWidget {
  const CustomerReferralPage({super.key});

  @override
  State<CustomerReferralPage> createState() => _CustomerReferralPageState();
}

class _CustomerReferralPageState extends State<CustomerReferralPage> {
  bool _isLoading = true;
  String _referralCode = "";
  int _totalReferred = 0;
  int _successfulConversions = 0;
  int _pointsEarned = 0;
  int _referrerBonus = 50;
  int _refereeBonus = 25;
  int _minOrderValue = 100;
  List<Map<String, dynamic>> _referralHistory = [];

  final TextEditingController _inputCodeController = TextEditingController();
  bool _isSubmittingCode = false;
  String? _applyResultMsg;
  bool _applySuccess = false;

  // Notification Preferences
  bool _orderNotifs = true;
  bool _promoNotifs = true;
  bool _isSavingPrefs = false;

  @override
  void initState() {
    super.initState();
    _fetchReferralAndPrefs();
  }

  @override
  void dispose() {
    _inputCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchReferralAndPrefs() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final token = await user.getIdToken();

      RestaurantProvider? restProvider;
      try {
        restProvider = Provider.of<RestaurantProvider?>(context, listen: false);
      } catch (_) {}
      final restId = restProvider?.config.id;

      // 1. Fetch Referral Data
      final refUrl = Uri.parse(
        "${ApiConfig.baseUrl}/user/referral${restId != null && restId.isNotEmpty ? '?restaurantId=$restId' : ''}",
      );
      final refRes = await http.get(refUrl, headers: {'Authorization': 'Bearer $token'});

      if (refRes.statusCode == 200) {
        final data = jsonDecode(refRes.body);
        _referralCode = data['referralCode']?.toString() ?? "";
        _referrerBonus = data['programConfig']?['referrerPoints'] ?? 50;
        _refereeBonus = data['programConfig']?['refereePoints'] ?? 25;
        _minOrderValue = data['programConfig']?['minOrderValue'] ?? 100;

        _totalReferred = data['stats']?['totalReferred'] ?? 0;
        _successfulConversions = data['stats']?['successfulConversions'] ?? 0;
        _pointsEarned = data['stats']?['totalPointsEarned'] ?? 0;

        final rawList = data['referrals'];
        if (rawList is List) {
          _referralHistory = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      // 2. Fetch Notification Preferences
      final notifUrl = Uri.parse("${ApiConfig.baseUrl}/user/notification-preferences");
      final notifRes = await http.get(notifUrl, headers: {'Authorization': 'Bearer $token'});
      if (notifRes.statusCode == 200) {
        final pData = jsonDecode(notifRes.body);
        final prefs = pData['preferences'];
        if (prefs is Map) {
          _orderNotifs = prefs['orders'] ?? true;
          _promoNotifs = prefs['promotional'] ?? true;
        }
      }
    } catch (e) {
      debugPrint("Error fetching customer referral info: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyFriendCode() async {
    final code = _inputCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isSubmittingCode = true;
      _applyResultMsg = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      RestaurantProvider? restProvider;
      try {
        restProvider = Provider.of<RestaurantProvider?>(context, listen: false);
      } catch (_) {}
      final restId = restProvider?.config.id;

      final url = Uri.parse("${ApiConfig.baseUrl}/user/apply-referral");
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "referralCode": code,
          if (restId != null && restId.isNotEmpty) "restaurantId": restId,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          _applySuccess = true;
          _applyResultMsg = data['message'] ?? "Referral code applied successfully!";
          _inputCodeController.clear();
        });
      } else {
        setState(() {
          _applySuccess = false;
          _applyResultMsg = data['error'] ?? "Failed to apply referral code.";
        });
      }
    } catch (e) {
      setState(() {
        _applySuccess = false;
        _applyResultMsg = "Connection error. Please try again.";
      });
    } finally {
      if (mounted) setState(() => _isSubmittingCode = false);
    }
  }

  Future<void> _saveNotificationPreferences(bool orders, bool promo) async {
    setState(() => _isSavingPrefs = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final url = Uri.parse("${ApiConfig.baseUrl}/user/notification-preferences");
      await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "orders": orders,
          "promotional": promo,
        }),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSavingPrefs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Refer & Earn", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Referral Hero Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFFB45309).withValues(alpha: 0.35), const Color(0xFF1E1E1E)]
                            : [const Color(0xFFFDE68A), Colors.amber.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.card_giftcard, size: 48, color: Color(0xFFD97706)),
                        const SizedBox(height: 12),
                        Text(
                          "Invite Friends, Earn Rewards!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Share your referral code with friends. When they complete their first eligible order (min ₹$_minOrderValue), you earn $_referrerBonus loyalty points, and they get $_refereeBonus bonus points!",
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Code Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141414) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD97706)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "YOUR CODE",
                                    style: TextStyle(fontSize: 10, color: secondaryTextColor, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _referralCode.isNotEmpty ? _referralCode : "LOADING...",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _referralCode.isNotEmpty
                                    ? () {
                                        Clipboard.setData(ClipboardData(text: _referralCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Referral code copied to clipboard!"),
                                            backgroundColor: Color(0xFF16A34A),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text("Copy"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD97706),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Referral Stats Overview
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          title: "Invited",
                          value: "$_totalReferred",
                          icon: Icons.group_outlined,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile(
                          title: "Completed",
                          value: "$_successfulConversions",
                          icon: Icons.check_circle_outline,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatTile(
                          title: "Points Won",
                          value: "$_pointsEarned",
                          icon: Icons.stars,
                          iconColor: Colors.amber,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Apply a Friend's Referral Code Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Have a Referral Code?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Enter a friend's code before your first order to get $_refereeBonus bonus points on completion.",
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputCodeController,
                                textCapitalization: TextCapitalization.characters,
                                style: TextStyle(color: primaryTextColor, fontSize: 13),
                                decoration: AppTheme.inputDecoration(
                                  isDark: isDark,
                                  hintText: "Enter friend's code",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _isSubmittingCode ? null : _applyFriendCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInput)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: _isSubmittingCode
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text("Apply", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (_applyResultMsg != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _applySuccess ? Icons.check_circle : Icons.error_outline,
                                color: _applySuccess ? const Color(0xFF16A34A) : Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _applyResultMsg!,
                                  style: TextStyle(
                                    color: _applySuccess ? const Color(0xFF16A34A) : Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Notification Preferences
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Notification Preferences",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Choose which notifications you wish to receive from Serveo:",
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "Order Status Updates",
                            style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            "Preparation, ready for pickup, and payment receipts",
                            style: TextStyle(color: secondaryTextColor, fontSize: 11),
                          ),
                          value: _orderNotifs,
                          activeColor: Colors.yellow,
                          onChanged: (val) {
                            setState(() => _orderNotifs = val);
                            _saveNotificationPreferences(_orderNotifs, _promoNotifs);
                          },
                        ),
                        const Divider(),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "Promotions & Special Offers",
                            style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            "Weekend coupons, festival discounts, and loyalty reward milestones",
                            style: TextStyle(color: secondaryTextColor, fontSize: 11),
                          ),
                          value: _promoNotifs,
                          activeColor: Colors.yellow,
                          onChanged: (val) {
                            setState(() => _promoNotifs = val);
                            _saveNotificationPreferences(_orderNotifs, _promoNotifs);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor ?? const Color(0xFFD97706)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: secondaryTextColor),
          ),
        ],
      ),
    );
  }
}
