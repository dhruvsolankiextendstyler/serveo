import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/api_config.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_spinner.dart';
import '../widgets/serveo_glass_container.dart';

class AdminMarketingPage extends StatefulWidget {
  const AdminMarketingPage({super.key});

  @override
  State<AdminMarketingPage> createState() => _AdminMarketingPageState();
}

class _AdminMarketingPageState extends State<AdminMarketingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Data
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _campaigns = [];
  Map<String, dynamic> _loyaltyConfig = {};
  List<Map<String, dynamic>> _loyaltyLedger = [];
  Map<String, dynamic> _referralConfig = {};
  Map<String, dynamic> _retentionData = {};
  String _retentionTimeframe = '30days';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _fetchCoupons(),
        _fetchCampaigns(),
        _fetchLoyaltyConfig(),
        _fetchReferralConfig(),
        _fetchRetentionAnalytics(_retentionTimeframe),
      ]);
    } catch (e) {
      _errorMessage = "Failed to load marketing data: $e";
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- API CALLS ---

  Future<void> _fetchCoupons() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/coupons"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['coupons'] is List) {
        _coupons = List<Map<String, dynamic>>.from(data['coupons']);
      }
    }
  }

  Future<void> _fetchCampaigns() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/campaigns"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['campaigns'] is List) {
        _campaigns = List<Map<String, dynamic>>.from(data['campaigns']);
      }
    }
  }

  Future<void> _fetchLoyaltyConfig() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/loyalty"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['loyaltyProgram'] is Map) {
        _loyaltyConfig = Map<String, dynamic>.from(data['loyaltyProgram']);
      }
    }
  }

  Future<void> _fetchReferralConfig() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/referrals"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['referralProgram'] is Map) {
        _referralConfig = Map<String, dynamic>.from(data['referralProgram']);
      }
    }
  }

  Future<void> _fetchRetentionAnalytics(String timeframe) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/analytics/retention?timeframe=$timeframe"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      _retentionData = Map<String, dynamic>.from(jsonDecode(res.body));
    }
  }

  // --- ACTIONS ---

  Future<void> _toggleCouponStatus(String id) async {
    final token = await _getToken();
    final res = await http.patch(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/coupons/$id/status"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      await _fetchCoupons();
      if (mounted) setState(() {});
    } else {
      _showErrorDialog("Failed to toggle coupon status: ${res.body}");
    }
  }

  Future<void> _deleteCoupon(String id) async {
    final token = await _getToken();
    final res = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/coupons/$id"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      await _fetchCoupons();
      if (mounted) setState(() {});
    } else {
      _showErrorDialog("Failed to delete coupon: ${res.body}");
    }
  }

  Future<void> _toggleCampaignStatus(String id) async {
    final token = await _getToken();
    final res = await http.patch(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/campaigns/$id/status"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      await _fetchCampaigns();
      if (mounted) setState(() {});
    } else {
      _showErrorDialog("Failed to toggle campaign status: ${res.body}");
    }
  }

  Future<void> _deleteCampaign(String id) async {
    final token = await _getToken();
    final res = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/campaigns/$id"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      await _fetchCampaigns();
      if (mounted) setState(() {});
    } else {
      _showErrorDialog("Failed to delete campaign: ${res.body}");
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showGlassDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
        title: const Text("Error", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  // --- DIALOGS: CREATE COUPON ---

  void _showCreateCouponDialog() {
    final codeCtrl = TextEditingController();
    String discountType = "percentage";
    final discountValCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController(text: "0");
    final maxDiscountCtrl = TextEditingController();
    final usageLimitCtrl = TextEditingController(text: "100");
    final perCustomerCtrl = TextEditingController(text: "1");
    final daysValidCtrl = TextEditingController(text: "30");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGlassDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
            title: const Row(
              children: [
                Icon(Icons.local_offer, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text("Create New Coupon", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Coupon Code *",
                        hintText: "e.g. SERVEO20",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: discountType,
                      dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Discount Type",
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: "percentage", child: Text("Percentage (%)")),
                        DropdownMenuItem(value: "fixed", child: Text("Fixed Amount (₹)")),
                        DropdownMenuItem(value: "free_delivery", child: Text("Free Delivery")),
                        DropdownMenuItem(value: "first_order", child: Text("First Order Discount (%)")),
                        DropdownMenuItem(value: "min_order", child: Text("Min Order Discount (₹)")),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => discountType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: discountValCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: discountType == "percentage" || discountType == "first_order"
                            ? "Discount Percentage (%) *"
                            : "Discount Amount (₹) *",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minOrderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Minimum Order Value (₹)",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxDiscountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Max Discount Cap (₹, optional)",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: usageLimitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: AppTheme.inputDecoration(
                              isDark: isDark,
                              labelText: "Total Uses",
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: perCustomerCtrl,
                            keyboardType: TextInputType.number,
                            decoration: AppTheme.inputDecoration(
                              isDark: isDark,
                              labelText: "Per Customer",
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: daysValidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Validity (Days from now)",
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInput)),
                ),
                onPressed: () async {
                  final code = codeCtrl.text.trim().toUpperCase();
                  final val = double.tryParse(discountValCtrl.text.trim()) ?? 0;
                  if (code.isEmpty || val <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please provide a valid code and discount value")),
                    );
                    return;
                  }

                  final days = int.tryParse(daysValidCtrl.text.trim()) ?? 30;
                  final validUntil = DateTime.now().add(Duration(days: days)).toIso8601String();

                  final parsedMaxDiscount = maxDiscountCtrl.text.isNotEmpty
                      ? double.tryParse(maxDiscountCtrl.text.trim())
                      : null;
                  final body = {
                    "code": code,
                    "discountType": discountType,
                    "discountValue": val,
                    "minOrderValue": double.tryParse(minOrderCtrl.text.trim()) ?? 0,
                    if (parsedMaxDiscount != null) ...{
                      "maxDiscountAmount": parsedMaxDiscount,
                      "maxDiscount": parsedMaxDiscount,
                    },
                    "totalUsageLimit": int.tryParse(usageLimitCtrl.text.trim()) ?? 100,
                    "perCustomerLimit": int.tryParse(perCustomerCtrl.text.trim()) ?? 1,
                    "endDate": validUntil,
                    "validUntil": validUntil,
                  };

                  Navigator.pop(ctx);
                  final token = await _getToken();
                  final res = await http.post(
                    Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/coupons"),
                    headers: {
                      "Content-Type": "application/json",
                      if (token != null) "Authorization": "Bearer $token",
                    },
                    body: jsonEncode(body),
                  );

                  if (res.statusCode == 201) {
                    await _fetchCoupons();
                    if (mounted) setState(() {});
                  } else {
                    _showErrorDialog("Failed to create coupon: ${res.body}");
                  }
                },
                child: const Text("Create Coupon"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DIALOGS: CREATE CAMPAIGN ---

  void _showCreateCampaignDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final bannerCtrl = TextEditingController();
    final couponCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: "14");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGlassDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text("Create Promotion", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: AppTheme.inputDecoration(
                    isDark: isDark,
                    labelText: "Campaign Title *",
                    hintText: "e.g. Weekend Biryani Feast",
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: AppTheme.inputDecoration(
                    isDark: isDark,
                    labelText: "Description",
                    hintText: "Short description shown on customer menu",
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bannerCtrl,
                  decoration: AppTheme.inputDecoration(
                    isDark: isDark,
                    labelText: "Banner Image URL (optional)",
                    hintText: "https://example.com/banner.jpg",
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: AppTheme.inputDecoration(
                    isDark: isDark,
                    labelText: "Associated Coupon Code (optional)",
                    hintText: "e.g. FEAST20",
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(
                    isDark: isDark,
                    labelText: "Duration (Days)",
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInput)),
            ),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a campaign title")),
                );
                return;
              }

              final days = int.tryParse(daysCtrl.text.trim()) ?? 14;
              final startDate = DateTime.now().toIso8601String();
              final endDate = DateTime.now().add(Duration(days: days)).toIso8601String();

              final body = {
                "title": title,
                "description": descCtrl.text.trim(),
                "bannerUrl": bannerCtrl.text.trim(),
                "couponCode": couponCtrl.text.trim().toUpperCase(),
                "startDate": startDate,
                "endDate": endDate,
              };

              Navigator.pop(ctx);
              final token = await _getToken();
              final res = await http.post(
                Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/campaigns"),
                headers: {
                  "Content-Type": "application/json",
                  if (token != null) "Authorization": "Bearer $token",
                },
                body: jsonEncode(body),
              );

              if (res.statusCode == 201) {
                await _fetchCampaigns();
                if (mounted) setState(() {});
              } else {
                _showErrorDialog("Failed to create campaign: ${res.body}");
              }
            },
            child: const Text("Create Campaign"),
          ),
        ],
      ),
    );
  }

  // --- SAVE LOYALTY CONFIG ---

  Future<void> _saveLoyaltyConfig() async {
    final token = await _getToken();
    final res = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/loyalty"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(_loyaltyConfig),
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loyalty configuration updated successfully!"), backgroundColor: Colors.green),
      );
      await _fetchLoyaltyConfig();
      if (mounted) setState(() {});
    } else {
      _showErrorDialog("Failed to save loyalty settings: ${res.body}");
    }
  }

  // --- SAVE REFERRAL CONFIG ---

  Future<void> _saveReferralConfig() async {
    final token = await _getToken();
    final res = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/referrals"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(_referralConfig),
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Referral configuration updated successfully!"), backgroundColor: Colors.green),
      );
      await _fetchReferralConfig();
      if (mounted) setState(() {});
    } else {
      _showErrorDialog("Failed to save referral settings: ${res.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;
    final restProvider = context.watch<RestaurantProvider>();
    final allowMarketing = restProvider.subscription?.allowMarketingAndLoyalty ?? true;

    final bgColor = isDark ? const Color(0xFF141414) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Plan Restriction Banner if on Starter
          if (!allowMarketing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Marketing & Loyalty requires a Growth or Premium plan. You are viewing in read-only mode.",
                      style: TextStyle(
                        color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Top Tab Bar
          Container(
            color: cardBg,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFFD97706),
              unselectedLabelColor: subtextColor,
              indicatorColor: const Color(0xFFD97706),
              tabs: const [
                Tab(icon: Icon(Icons.local_offer, size: 18), text: "Coupons"),
                Tab(icon: Icon(Icons.campaign, size: 18), text: "Promotions"),
                Tab(icon: Icon(Icons.stars, size: 18), text: "Loyalty"),
                Tab(icon: Icon(Icons.group_add, size: 18), text: "Referrals"),
                Tab(icon: Icon(Icons.insights, size: 18), text: "Retention"),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: ServeoSpinner())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCouponsTab(cardBg, borderColor, textColor, subtextColor, allowMarketing),
                      _buildCampaignsTab(cardBg, borderColor, textColor, subtextColor, allowMarketing),
                      _buildLoyaltyTab(cardBg, borderColor, textColor, subtextColor, allowMarketing),
                      _buildReferralsTab(cardBg, borderColor, textColor, subtextColor, allowMarketing),
                      _buildRetentionTab(cardBg, borderColor, textColor, subtextColor),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: COUPONS
  // ==========================================
  Widget _buildCouponsTab(Color cardBg, Color borderColor, Color textColor, Color subtextColor, bool allowMarketing) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: allowMarketing
          ? FloatingActionButton.extended(
              heroTag: 'createCouponBtn',
              backgroundColor: const Color(0xFFD97706),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("New Coupon", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCreateCouponDialog,
            )
          : null,
      body: _coupons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 48, color: subtextColor),
                  const SizedBox(height: 12),
                  Text("No coupons created yet", style: TextStyle(color: textColor, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text("Create coupons to attract customers and increase order size.", style: TextStyle(color: subtextColor, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _coupons.length,
              itemBuilder: (ctx, idx) {
                final coupon = _coupons[idx];
                final code = coupon['code'] ?? '';
                final type = coupon['discountType'] ?? 'percentage';
                final val = coupon['discountValue'] ?? 0;
                final isActive = coupon['isActive'] == true;
                final totalLimit = coupon['totalUsageLimit'] ?? 0;
                final currentUsage = coupon['currentUsageCount'] ?? 0;
                final minOrder = coupon['minOrderValue'] ?? 0;
                final id = coupon['_id']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_offer, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  code,
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? "ACTIVE" : "INACTIVE",
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type == "percentage" || type == "first_order"
                                  ? "$val% OFF (Min ₹$minOrder)"
                                  : "₹$val OFF (Min ₹$minOrder)",
                              style: TextStyle(color: subtextColor, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Used: $currentUsage / $totalLimit times",
                              style: TextStyle(color: subtextColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (allowMarketing) ...[
                        Switch.adaptive(
                          value: isActive,
                          activeColor: const Color(0xFFD97706),
                          onChanged: (_) => _toggleCouponStatus(id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: "Delete Coupon",
                          onPressed: () => _deleteCoupon(id),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 2: PROMOTIONS / CAMPAIGNS
  // ==========================================
  Widget _buildCampaignsTab(Color cardBg, Color borderColor, Color textColor, Color subtextColor, bool allowMarketing) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: allowMarketing
          ? FloatingActionButton.extended(
              heroTag: 'createCampaignBtn',
              backgroundColor: const Color(0xFFD97706),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("New Campaign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showCreateCampaignDialog,
            )
          : null,
      body: _campaigns.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 48, color: subtextColor),
                  const SizedBox(height: 12),
                  Text("No marketing campaigns yet", style: TextStyle(color: textColor, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text("Promote festival offers, weekend specials, or combo deals.", style: TextStyle(color: subtextColor, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _campaigns.length,
              itemBuilder: (ctx, idx) {
                final c = _campaigns[idx];
                final title = c['title'] ?? '';
                final desc = c['description'] ?? '';
                final isActive = c['isActive'] == true;
                final views = c['viewCount'] ?? 0;
                final clicks = c['clickCount'] ?? 0;
                final coupon = c['couponCode'] ?? '';
                final id = c['_id']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(desc, style: TextStyle(color: subtextColor, fontSize: 13)),
                                ],
                              ],
                            ),
                          ),
                          if (allowMarketing) ...[
                            Switch.adaptive(
                              value: isActive,
                              activeColor: const Color(0xFFD97706),
                              onChanged: (_) => _toggleCampaignStatus(id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: "Delete Campaign",
                              onPressed: () => _deleteCampaign(id),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (coupon.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "CODE: $coupon",
                                style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text("Views: $views", style: TextStyle(color: subtextColor, fontSize: 12)),
                          const SizedBox(width: 12),
                          Text("Clicks: $clicks", style: TextStyle(color: subtextColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 3: LOYALTY PROGRAM
  // ==========================================
  Widget _buildLoyaltyTab(Color cardBg, Color borderColor, Color textColor, Color subtextColor, bool allowMarketing) {
    final isEnabled = _loyaltyConfig['enabled'] == true;
    final pointsPerRupee = _loyaltyConfig['pointsPerRupee'] ?? 0.1;
    final minOrder = _loyaltyConfig['minOrderValue'] ?? 100;
    final allowOnDiscounted = _loyaltyConfig['allowPointsOnDiscountedOrders'] ?? true;
    final rewards = (_loyaltyConfig['rewardsCatalog'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Loyalty Toggle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFD97706), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Customer Loyalty Program",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Switch.adaptive(
                      value: isEnabled,
                      activeColor: const Color(0xFFD97706),
                      onChanged: allowMarketing
                          ? (val) {
                              setState(() {
                                _loyaltyConfig['enabled'] = val;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Reward your frequent diners with loyalty points they can earn on completed orders and redeem at checkout.",
                  style: TextStyle(color: subtextColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Points per ₹ Spent", style: TextStyle(color: subtextColor, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: pointsPerRupee.toString(),
                            enabled: allowMarketing,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: AppTheme.inputDecoration(isDark: isDark, isDense: true),
                            onChanged: (val) {
                              _loyaltyConfig['pointsPerRupee'] = double.tryParse(val) ?? 0.1;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Min Order Value (₹)", style: TextStyle(color: subtextColor, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: minOrder.toString(),
                            enabled: allowMarketing,
                            keyboardType: TextInputType.number,
                            decoration: AppTheme.inputDecoration(isDark: isDark, isDense: true),
                            onChanged: (val) {
                              _loyaltyConfig['minOrderValue'] = int.tryParse(val) ?? 100;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text("Allow earning points on discounted orders", style: TextStyle(color: textColor, fontSize: 13)),
                  value: allowOnDiscounted,
                  activeColor: const Color(0xFFD97706),
                  contentPadding: EdgeInsets.zero,
                  onChanged: allowMarketing
                      ? (val) {
                          setState(() {
                            _loyaltyConfig['allowPointsOnDiscountedOrders'] = val ?? true;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                if (allowMarketing)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text("Save Loyalty Rules"),
                      onPressed: _saveLoyaltyConfig,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Rewards Catalog", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
              if (allowMarketing)
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add Reward"),
                  onPressed: () {
                    _showAddRewardDialog();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (rewards.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text("No rewards configured. Add rewards for customers to redeem.", style: TextStyle(color: subtextColor)),
              ),
            )
          else
            ...rewards.map((r) {
              final name = r['rewardName'] ?? 'Reward';
              final points = r['pointsRequired'] ?? 100;
              final val = r['discountValue'] ?? 50;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "$name — ₹$val OFF ($points Points)",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    if (allowMarketing)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          setState(() {
                            (_loyaltyConfig['rewardsCatalog'] as List).remove(r);
                          });
                          _saveLoyaltyConfig();
                        },
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddRewardDialog() {
    final nameCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: "100");
    final valCtrl = TextEditingController(text: "50");
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGlassDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
        title: const Text("Add Redeemable Reward", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: AppTheme.inputDecoration(
                isDark: isDark,
                labelText: "Reward Name",
                hintText: "e.g. ₹50 Off Order",
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: AppTheme.inputDecoration(
                isDark: isDark,
                labelText: "Points Required",
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              keyboardType: TextInputType.number,
              decoration: AppTheme.inputDecoration(
                isDark: isDark,
                labelText: "Discount Amount (₹)",
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInput)),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final pts = int.tryParse(pointsCtrl.text.trim()) ?? 100;
              final disc = double.tryParse(valCtrl.text.trim()) ?? 50;
              if (name.isEmpty) return;

              Navigator.pop(ctx);
              setState(() {
                if (_loyaltyConfig['rewardsCatalog'] == null) {
                  _loyaltyConfig['rewardsCatalog'] = [];
                }
                (_loyaltyConfig['rewardsCatalog'] as List).add({
                  "rewardName": name,
                  "pointsRequired": pts,
                  "discountValue": disc,
                  "isActive": true,
                });
              });
              _saveLoyaltyConfig();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: REFERRALS PROGRAM
  // ==========================================
  Widget _buildReferralsTab(Color cardBg, Color borderColor, Color textColor, Color subtextColor, bool allowMarketing) {
    final isEnabled = _referralConfig['enabled'] == true;
    final referrerBonus = _referralConfig['referrerBonusPoints'] ?? 50;
    final refereeBonus = _referralConfig['refereeBonusPoints'] ?? 25;
    final minOrder = _referralConfig['minOrderValueForReward'] ?? 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Customer Referral Program",
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  activeColor: const Color(0xFFD97706),
                  onChanged: allowMarketing
                      ? (val) {
                          setState(() {
                            _referralConfig['enabled'] = val;
                          });
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Turn satisfied diners into ambassadors. Reward them with loyalty bonus points when their invited friends complete their first eligible order.",
              style: TextStyle(color: subtextColor, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Referrer Bonus Points", style: TextStyle(color: subtextColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: referrerBonus.toString(),
                        enabled: allowMarketing,
                        keyboardType: TextInputType.number,
                        decoration: AppTheme.inputDecoration(isDark: isDark, isDense: true),
                        onChanged: (val) {
                          _referralConfig['referrerBonusPoints'] = int.tryParse(val) ?? 50;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Referee (Friend) Bonus", style: TextStyle(color: subtextColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: refereeBonus.toString(),
                        enabled: allowMarketing,
                        keyboardType: TextInputType.number,
                        decoration: AppTheme.inputDecoration(isDark: isDark, isDense: true),
                        onChanged: (val) {
                          _referralConfig['refereeBonusPoints'] = int.tryParse(val) ?? 25;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Min Order Value for First Order (₹)", style: TextStyle(color: subtextColor, fontSize: 12)),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: minOrder.toString(),
                  enabled: allowMarketing,
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(isDark: isDark, isDense: true),
                  onChanged: (val) {
                    _referralConfig['minOrderValueForReward'] = int.tryParse(val) ?? 100;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (allowMarketing)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text("Save Referral Program"),
                  onPressed: _saveReferralConfig,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 5: RETENTION ANALYTICS
  // ==========================================
  Widget _buildRetentionTab(Color cardBg, Color borderColor, Color textColor, Color subtextColor) {
    final customers = (_retentionData['customers'] as Map?) ?? {};
    final revenue = (_retentionData['revenue'] as Map?) ?? {};
    final coupons = (_retentionData['coupons'] as Map?) ?? {};
    final loyalty = (_retentionData['loyalty'] as Map?) ?? {};
    final referrals = (_retentionData['referrals'] as Map?) ?? {};
    final campaigns = (_retentionData['campaigns'] as List?) ?? [];

    final totalActive = customers['totalActive'] ?? 0;
    final newCustomers = customers['newCustomers'] ?? 0;
    final returningCustomers = customers['returningCustomers'] ?? 0;
    final repeatRate = customers['repeatOrderRate'] ?? 0;
    final orderFreq = customers['orderFrequency'] ?? 0;

    final gross = revenue['grossSales'] ?? 0;
    final discounts = revenue['totalDiscounts'] ?? 0;
    final net = revenue['netPaidRevenue'] ?? 0;
    final aov = revenue['averageOrderValue'] ?? 0;

    final couponRedemptions = coupons['redemptionCount'] ?? 0;
    final couponSales = coupons['attributedSales'] ?? 0;

    final pointsEarned = loyalty['pointsEarned'] ?? 0;
    final pointsRedeemed = loyalty['pointsRedeemed'] ?? 0;

    final totalReferrals = referrals['totalReferrals'] ?? 0;
    final convertedReferrals = referrals['convertedReferrals'] ?? 0;
    final conversionRate = referrals['conversionRate'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeframe Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeframeChip("Today", "today"),
                _buildTimeframeChip("Yesterday", "yesterday"),
                _buildTimeframeChip("Last 7 Days", "7days"),
                _buildTimeframeChip("Last 30 Days", "30days"),
                _buildTimeframeChip("All Time", "all"),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key Metrics Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: "Active Customers",
                  value: "$totalActive",
                  subtitle: "$newCustomers New • $returningCustomers Returning",
                  badge: "$repeatRate% Repeat",
                  icon: Icons.people,
                  color: Colors.blueAccent,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: "Net Paid Revenue",
                  value: "₹$net",
                  subtitle: "Gross ₹$gross • Disc ₹$discounts",
                  badge: "AOV: ₹$aov",
                  icon: Icons.currency_rupee,
                  color: Colors.green,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: "Coupons Used",
                  value: "$couponRedemptions",
                  subtitle: "Attributed: ₹$couponSales",
                  icon: Icons.local_offer,
                  color: const Color(0xFFD97706),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: "Loyalty Points",
                  value: "+$pointsEarned",
                  subtitle: "Redeemed: -$pointsRedeemed pts",
                  icon: Icons.stars,
                  color: Colors.purpleAccent,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            title: "Referral Program Conversions",
            value: "$convertedReferrals / $totalReferrals",
            subtitle: "Completed first orders from invited friends",
            badge: "$conversionRate% Conversion Rate",
            icon: Icons.group_add,
            color: Colors.teal,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtextColor: subtextColor,
          ),

          const SizedBox(height: 20),
          Text("Campaign Attribution & Performance", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          if (campaigns.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text("No campaign attribution data recorded yet.", style: TextStyle(color: subtextColor)),
              ),
            )
          else
            ...campaigns.map((c) {
              final title = c['title'] ?? '';
              final views = c['viewCount'] ?? 0;
              final clicks = c['clickCount'] ?? 0;
              final ctr = c['ctr'] ?? 0;
              final coupon = c['couponCode'] ?? '';
              final usage = c['couponUsage'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text("Views: $views • Clicks: $clicks • CTR: $ctr%", style: TextStyle(color: subtextColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (coupon.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$coupon ($usage used)",
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTimeframeChip(String label, String value) {
    final isSelected = _retentionTimeframe == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFD97706),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _retentionTimeframe = value);
            _fetchRetentionAnalytics(value).then((_) {
              if (mounted) setState(() {});
            });
          }
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    String? badge,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: subtextColor, fontSize: 11)),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
