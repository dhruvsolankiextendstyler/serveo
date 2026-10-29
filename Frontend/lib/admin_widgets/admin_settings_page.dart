import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_spinner.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _openTimeController;
  late TextEditingController _closeTimeController;
  late TextEditingController _prepTimeController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalController;
  late TextEditingController _announcementController;
  late TextEditingController _pauseReasonController;

  List<String> _selectedDays = [];
  bool _isPaused = false;
  bool _initialized = false;

  final List<String> _allDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _openTimeController = TextEditingController();
    _closeTimeController = TextEditingController();
    _prepTimeController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _postalController = TextEditingController();
    _announcementController = TextEditingController();
    _pauseReasonController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() async {
    final provider = context.read<RestaurantProvider>();
    await provider.fetchAdminSettings();
    if (mounted) {
      _syncControllers(provider.config);
    }
  }

  void _syncControllers(RestaurantConfig cfg) {
    setState(() {
      _nameController.text = cfg.name;
      _descController.text = cfg.description;
      _openTimeController.text = cfg.openingTime;
      _closeTimeController.text = cfg.closingTime;
      _prepTimeController.text = cfg.defaultEstimatedPrepTime.toString();
      _phoneController.text = cfg.contactPhone;
      _emailController.text = cfg.contactEmail;
      _streetController.text = cfg.addressStreet;
      _cityController.text = cfg.addressCity;
      _stateController.text = cfg.addressState;
      _postalController.text = cfg.addressPostalCode;
      _announcementController.text = cfg.announcement;
      _pauseReasonController.text = cfg.pauseReason;
      _selectedDays = List<String>.from(cfg.operatingDays);
      _isPaused = cfg.isOrderAcceptancePaused;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    _prepTimeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _announcementController.dispose();
    _pauseReasonController.dispose();
    super.dispose();
  }

  void _handleSaveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one operating day"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final provider = context.read<RestaurantProvider>();
    final updates = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'openingTime': _openTimeController.text.trim(),
      'closingTime': _closeTimeController.text.trim(),
      'operatingDays': _selectedDays,
      'defaultEstimatedPrepTime': int.tryParse(_prepTimeController.text.trim()) ?? 20,
      'currency': 'INR',
      'contact': {
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      },
      'address': {
        'street': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'postalCode': _postalController.text.trim(),
      },
      'displayPreferences': {
        'announcement': _announcementController.text.trim(),
        'showPrepTime': true,
        'showDietaryBadges': true,
      },
    };

    final success = await provider.updateSettings(updates);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Restaurant business settings saved successfully!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Failed to save settings."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleTogglePause(bool newPaused) async {
    final provider = context.read<RestaurantProvider>();
    final reason = _pauseReasonController.text.trim();

    setState(() => _isPaused = newPaused);

    final success = await provider.togglePauseOrders(newPaused, reason: reason);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPaused
              ? "Order acceptance paused. Customers can browse menu but cannot checkout."
              : "Order acceptance resumed! Restaurant is open for orders."),
          backgroundColor: newPaused ? const Color(0xFFD97706) : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _isPaused = !newPaused); // Revert
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Failed to toggle pause status."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _copyQrUrl(String? url) {
    if (url == null || url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Public menu URL copied to clipboard!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    if (provider.isLoading && !_initialized) {
      return const Center(child: ServeoSpinner());
    }

    final cfg = provider.config;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAdminSettings(),
        color: Colors.yellow,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔹 SECTION 1: LIVE STATUS & EMERGENCY PAUSE BANNER
                _buildLiveStatusCard(cfg, cardBg, borderColor, primaryTextColor, secondaryTextColor, isDark),
                const SizedBox(height: 16),

                // 🔹 SECTION 2: QR CODE MENU CARD
                _buildQrMenuCard(provider, cardBg, borderColor, primaryTextColor, secondaryTextColor, isDark),
                const SizedBox(height: 16),

                // 🔹 SECTION 3: RESTAURANT PROFILE
                _buildProfileCard(cardBg, borderColor, primaryTextColor, isDark),
                const SizedBox(height: 16),

                // 🔹 SECTION 4: OPERATING HOURS & SCHEDULE
                _buildScheduleCard(cardBg, borderColor, primaryTextColor, secondaryTextColor, isDark),
                const SizedBox(height: 16),

                // 🔹 SECTION 5: ADDRESS & CONTACT
                _buildContactCard(cardBg, borderColor, primaryTextColor, isDark),
                const SizedBox(height: 16),

                // 🔹 SECTION 6: DISPLAY PREFERENCES
                _buildPreferencesCard(cardBg, borderColor, primaryTextColor, isDark),
                const SizedBox(height: 24),

                // 🔹 SAVE BUTTON
                ElevatedButton.icon(
                  key: const Key('admin_save_settings_btn'),
                  onPressed: provider.isSaving ? null : _handleSaveSettings,
                  icon: provider.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save_outlined, color: Colors.black),
                  label: Text(
                    provider.isSaving ? "SAVING SETTINGS..." : "SAVE BUSINESS SETTINGS",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard(
    RestaurantConfig cfg,
    Color bg,
    Color border,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    Color statusColor = Colors.green;
    String statusTitle = "OPEN & ACCEPTING ORDERS";
    IconData statusIcon = Icons.check_circle_outline;

    if (cfg.isPaused || _isPaused) {
      statusColor = const Color(0xFFD97706);
      statusTitle = "ORDERS TEMPORARILY PAUSED";
      statusIcon = Icons.pause_circle_outline;
    } else if (cfg.isClosed) {
      statusColor = Colors.redAccent;
      statusTitle = "CURRENTLY CLOSED";
      statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      cfg.availabilityReason.isNotEmpty
                          ? cfg.availabilityReason
                          : "Today's hours: ${cfg.openingTime} - ${cfg.closingTime} (${cfg.timezone})",
                      style: TextStyle(color: subtextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Emergency Pause Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pause New Orders",
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      "Temporarily halt incoming orders without modifying operating schedule.",
                      style: TextStyle(color: subtextColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('admin_pause_orders_switch'),
                value: _isPaused,
                activeThumbColor: Colors.yellow,
                onChanged: _handleTogglePause,
              ),
            ],
          ),

          if (_isPaused) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pauseReasonController,
              decoration: InputDecoration(
                labelText: "Pause Reason (Customer-facing)",
                hintText: "e.g. Kitchen rush, back in 20 minutes",
                filled: true,
                fillColor: isDark ? const Color(0xFF141414) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _handleTogglePause(true),
                icon: const Icon(Icons.update, size: 16),
                label: const Text("Update Reason"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrMenuCard(
    RestaurantProvider provider,
    Color bg,
    Color border,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final qrData = provider.qrDataUrl;
    final menuUrl = provider.publicMenuUrl ?? "https://serveo-foods.onrender.com/menu/${provider.config.slug}";

    ImageProvider? qrImage;
    if (qrData != null && qrData.startsWith("data:image/png;base64,")) {
      try {
        final b64 = qrData.replaceFirst("data:image/png;base64,", "");
        qrImage = MemoryImage(base64Decode(b64));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Text(
                "Digital Restaurant QR Menu",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Customers scan this QR code to view your digital menu in any mobile browser without installing the app.",
            style: TextStyle(color: subtextColor, fontSize: 12),
          ),
          const SizedBox(height: 16),

          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: qrImage != null
                  ? Image(image: qrImage, width: 180, height: 180, fit: BoxFit.contain)
                  : Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code, size: 80, color: Colors.black54),
                          const SizedBox(height: 8),
                          Text(provider.config.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Menu URL bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    menuUrl,
                    style: TextStyle(color: textColor, fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: "Copy Link",
                  onPressed: () => _copyQrUrl(menuUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyQrUrl(menuUrl),
                icon: const Icon(Icons.share, size: 16),
                label: const Text("Share Link"),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("QR code ready for counter standees & table cards!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                icon: const Icon(Icons.print_outlined, size: 16, color: Colors.black),
                label: const Text("Print / Save", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Color bg, Color border, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Restaurant Identity",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('admin_restaurant_name_input'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Restaurant Name *",
              hintText: "e.g. Serveo Bistro Central",
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Restaurant name is required" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Tagline / Description",
              hintText: "e.g. Fresh meals & quick snacks ready for counter pickup",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    Color bg,
    Color border,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Operating Hours & Schedule",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            "Orders outside operating hours are blocked on both frontend and backend.",
            style: TextStyle(color: subtextColor, fontSize: 12),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('admin_opening_time_input'),
                  controller: _openTimeController,
                  decoration: const InputDecoration(
                    labelText: "Opening Time (24h) *",
                    hintText: "09:00",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
                    if (v == null || !regex.hasMatch(v.trim())) {
                      return "Format: HH:mm (e.g. 09:00)";
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('admin_closing_time_input'),
                  controller: _closeTimeController,
                  decoration: const InputDecoration(
                    labelText: "Closing Time (24h) *",
                    hintText: "22:00",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
                    if (v == null || !regex.hasMatch(v.trim())) {
                      return "Format: HH:mm (e.g. 22:00)";
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            "Operating Days",
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allDays.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day.substring(0, 3)),
                selected: isSelected,
                selectedColor: Colors.yellow,
                checkmarkColor: Colors.black,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _prepTimeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Default Estimated Preparation Time (Minutes)",
              hintText: "20",
              border: OutlineInputBorder(),
              suffixText: "mins",
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 5 || n > 120) return "Enter between 5 and 120 minutes";
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Color bg, Color border, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Address & Contact Information",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: "Contact Phone",
              hintText: "+91 98765 43210",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: "Support Email",
              hintText: "support@restaurant.com",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(
              labelText: "Street Address",
              hintText: "Central Food Court, Campus Block A",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: "City", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _postalController,
                  decoration: const InputDecoration(labelText: "Pincode", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(Color bg, Color border, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Customer Display Preferences",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _announcementController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Announcement Banner (Optional)",
              hintText: "e.g. 10% discount on smoothies between 4 PM and 6 PM!",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

