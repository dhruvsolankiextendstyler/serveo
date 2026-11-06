import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/restaurant_provider.dart';
import '../utils/theme_provider.dart';
import '../widgets/breakbite_spinner.dart';
import '../widgets/serveo_glass_container.dart';

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
  List<OperatingDaySchedule> _dailySchedules = [];
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

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  String _formatTimeOfDay12(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour12 = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final h = hour12.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m $period";
  }

  String _formatString12(String timeStr) {
    return _formatTimeOfDay12(_parseTimeOfDay(timeStr));
  }

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

      if (cfg.schedule.isNotEmpty) {
        _dailySchedules = List<OperatingDaySchedule>.from(cfg.schedule);
      } else {
        _dailySchedules = _allDays.map((day) => OperatingDaySchedule(
          day: day,
          isOpen: cfg.operatingDays.contains(day),
          openTime: cfg.openingTime,
          closeTime: cfg.closingTime,
        )).toList();
      }

      _isPaused = cfg.isOrderAcceptancePaused;
      _initialized = true;
    });
  }

  Future<void> _pickGeneralTime({required bool isOpening, required bool isDark}) async {
    final currentStr = isOpening ? _openTimeController.text : _closeTimeController.text;
    final initial = _parseTimeOfDay(currentStr);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isOpening ? "SELECT OPENING TIME" : "SELECT CLOSING TIME",
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Colors.yellow,
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFD97706),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1F2937),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted24 = _formatTimeOfDay24(picked);
      setState(() {
        if (isOpening) {
          _openTimeController.text = formatted24;
        } else {
          _closeTimeController.text = formatted24;
        }
      });
    }
  }

  Future<void> _pickTimeForDay({
    required int dayIndex,
    required bool isOpening,
    required bool isDark,
  }) async {
    final schedule = _dailySchedules[dayIndex];
    final currentStr = isOpening ? schedule.openTime : schedule.closeTime;
    final initial = _parseTimeOfDay(currentStr);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isOpening ? "SELECT ${schedule.day.toUpperCase()} OPENING TIME" : "SELECT ${schedule.day.toUpperCase()} CLOSING TIME",
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Colors.yellow,
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFFD97706),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1F2937),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted24 = _formatTimeOfDay24(picked);
      setState(() {
        _dailySchedules[dayIndex] = isOpening
            ? schedule.copyWith(openTime: formatted24)
            : schedule.copyWith(closeTime: formatted24);

        if (dayIndex == 0 || schedule.day == "Monday") {
          if (isOpening) _openTimeController.text = formatted24;
          else _closeTimeController.text = formatted24;
        }
      });
    }
  }

  void _applyHoursToAllDays(String openTime, String closeTime) {
    setState(() {
      _dailySchedules = _dailySchedules.map((s) {
        return s.copyWith(openTime: openTime, closeTime: closeTime);
      }).toList();
      _openTimeController.text = openTime;
      _closeTimeController.text = closeTime;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Applied $openTime — $closeTime to all days!"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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

    // Sync selectedDays from daily schedules
    final activeDays = _dailySchedules.where((s) => s.isOpen).map((s) => s.day).toList();
    if (activeDays.isNotEmpty) {
      _selectedDays = activeDays;
    }

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
      'schedule': _dailySchedules.map((s) => s.toJson()).toList(),
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
      // Reload admin settings & refresh public info to guarantee synchronization
      await provider.fetchAdminSettings();
      await provider.fetchPublicInfo(identifier: provider.config.slug);

      if (mounted) {
        _syncControllers(provider.config);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Restaurant business settings saved successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

                // 🔹 SECTION 1B: SUBSCRIPTION & OPERATIONAL USAGE CARD
                _buildSubscriptionCard(provider, cardBg, borderColor, primaryTextColor, secondaryTextColor, isDark),
                const SizedBox(height: 16),

                // 🔹 SECTION 1C: STAFF ACCOUNTS & ROLES (RBAC) CARD
                _buildStaffManagementCard(provider, cardBg, borderColor, primaryTextColor, secondaryTextColor, isDark),
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
              decoration: AppTheme.inputDecoration(
                isDark: isDark,
                labelText: "Pause Reason (Customer-facing)",
                hintText: "e.g. Kitchen rush, back in 20 minutes",
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
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Restaurant Name *",
              hintText: "e.g. Serveo Bistro Central",
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Restaurant name is required" : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Tagline / Description",
              hintText: "e.g. Fresh meals & quick snacks ready for counter pickup",
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
          Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Text(
                "Operating Hours & Schedule",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Tap any time field to open the clock-style time picker. Changes are saved to MongoDB and instantly govern online ordering availability.",
            style: TextStyle(color: subtextColor, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Default / Quick Hours Header
          Text(
            "Default Operating Hours",
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickGeneralTime(isOpening: true, isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  child: IgnorePointer(
                    child: TextFormField(
                      key: const Key('admin_opening_time_input'),
                      controller: _openTimeController,
                      readOnly: true,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Opening Time (24h) *",
                        hintText: "09:00",
                        prefixIcon: const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFFD97706)),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickGeneralTime(isOpening: false, isDark: isDark),
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  child: IgnorePointer(
                    child: TextFormField(
                      key: const Key('admin_closing_time_input'),
                      controller: _closeTimeController,
                      readOnly: true,
                      decoration: AppTheme.inputDecoration(
                        isDark: isDark,
                        labelText: "Closing Time (24h) *",
                        hintText: "22:00",
                        prefixIcon: const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFFD97706)),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _applyHoursToAllDays(
                _openTimeController.text.trim(),
                _closeTimeController.text.trim(),
              ),
              icon: const Icon(Icons.sync, size: 16, color: Color(0xFFD97706)),
              label: const Text(
                "Apply to all days",
                style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Daily Operating Hours List
          Text(
            "Daily Operating Hours (Clock-Style)",
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailySchedules.length,
              separatorBuilder: (_, __) => Divider(color: border, height: 1),
              itemBuilder: (context, index) {
                final schedule = _dailySchedules[index];
                final isOpen = schedule.isOpen;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                schedule.day,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOpen ? "Open" : "Closed",
                                  style: TextStyle(
                                    color: isOpen ? Colors.green : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: isOpen,
                            activeThumbColor: Colors.yellow,
                            onChanged: (val) {
                              setState(() {
                                _dailySchedules[index] = schedule.copyWith(isOpen: val);
                                if (val) {
                                  if (!_selectedDays.contains(schedule.day)) {
                                    _selectedDays.add(schedule.day);
                                  }
                                } else {
                                  _selectedDays.remove(schedule.day);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (isOpen) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Opening Time Button
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickTimeForDay(dayIndex: index, isOpening: true, isDark: isDark),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFD97706)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _formatString12(schedule.openTime),
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "to",
                                style: TextStyle(color: subtextColor, fontSize: 12),
                              ),
                            ),
                            // Closing Time Button
                            Expanded(
                              child: InkWell(
                                onTap: () => _pickTimeForDay(dayIndex: index, isOpening: false, isDark: isDark),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFD97706)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _formatString12(schedule.closeTime),
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _prepTimeController,
            keyboardType: TextInputType.number,
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Default Estimated Preparation Time (Minutes)",
              hintText: "20",
              suffixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Text("mins", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              ),
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
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Contact Phone",
              hintText: "+91 98765 43210",
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Support Email",
              hintText: "support@restaurant.com",
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _streetController,
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Street Address",
              hintText: "Central Food Court, Campus Block A",
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: AppTheme.inputDecoration(isDark: isDark, labelText: "City"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: AppTheme.inputDecoration(isDark: isDark, labelText: "State"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _postalController,
                  decoration: AppTheme.inputDecoration(isDark: isDark, labelText: "Pincode"),
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
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "Announcement Banner (Optional)",
              hintText: "e.g. 10% discount on smoothies between 4 PM and 6 PM!",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    RestaurantProvider provider,
    Color bg,
    Color border,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final sub = provider.subscription;
    final planName = sub?.planName ?? "Starter";
    final planStatus = (sub?.status ?? "ACTIVE").toUpperCase();
    final itemsCurrent = sub?.activeItemsCurrent ?? 0;
    final itemsMax = sub?.activeItemsMax ?? 20;
    final staffCurrent = sub?.staffCurrent ?? 1;
    final staffMax = sub?.staffMax ?? 2;

    final itemsRatio = itemsMax > 0 ? (itemsCurrent / itemsMax).clamp(0.0, 1.0) : 0.0;
    final staffRatio = staffMax > 0 ? (staffCurrent / staffMax).clamp(0.0, 1.0) : 0.0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_membership_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Commercial Subscription",
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 0.8),
                ),
                child: Text(
                  "$planName • $planStatus",
                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Menu Items Usage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Active Menu Items", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
              Text("$itemsCurrent / $itemsMax items", style: TextStyle(color: subtextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: itemsRatio,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(itemsRatio >= 1.0 ? Colors.redAccent : Colors.amber),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),

          // Staff Accounts Usage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Staff Accounts Capacity", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
              Text("$staffCurrent / $staffMax accounts", style: TextStyle(color: subtextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: staffRatio,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(staffRatio >= 1.0 ? Colors.redAccent : Colors.amber),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffManagementCard(
    RestaurantProvider provider,
    Color bg,
    Color border,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final staffList = provider.staff;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Staff Accounts & Roles (RBAC)",
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              TextButton.icon(
                key: const Key('admin_add_staff_btn'),
                onPressed: () => _showAddStaffDialog(context, provider),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text("Add Staff", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (staffList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "No additional staff accounts configured. Add managers, kitchen, or cashier staff above.",
                style: TextStyle(color: subtextColor, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffList.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final member = staffList[index];
                Color roleColor = Colors.blue;
                if (member.role == 'owner') roleColor = Colors.amber;
                if (member.role == 'kitchen') roleColor = Colors.deepOrange;
                if (member.role == 'cashier') roleColor = Colors.green;
                if (member.role == 'viewer') roleColor = Colors.grey;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: roleColor.withValues(alpha: 0.15),
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : 'S',
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name.isNotEmpty ? member.name : member.email,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            member.email,
                            style: TextStyle(color: subtextColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: roleColor, width: 0.8),
                      ),
                      child: Text(
                        member.role.toUpperCase(),
                        style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: subtextColor),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _showEditRoleDialog(context, provider, member);
                        } else if (value == 'delete') {
                          final success = await provider.removeStaff(member.id);
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.errorMessage ?? "Failed to remove staff"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text("Change Role")),
                        const PopupMenuItem(value: 'delete', child: Text("Remove", style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, RestaurantProvider provider) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'manager';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGlassDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
          title: const Text("Add Staff Account", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: AppTheme.inputDecoration(
                  isDark: isDark,
                  labelText: "Staff Email",
                  hintText: "staff@restaurant.com",
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: AppTheme.inputDecoration(
                  isDark: isDark,
                  labelText: "Full Name",
                  hintText: "e.g. John Doe",
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                decoration: AppTheme.inputDecoration(
                  isDark: isDark,
                  labelText: "Staff Role",
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text("Owner (Full Access)")),
                  DropdownMenuItem(value: 'manager', child: Text("Manager (Operations)")),
                  DropdownMenuItem(value: 'kitchen', child: Text("Kitchen (Cooking & Orders)")),
                  DropdownMenuItem(value: 'cashier', child: Text("Cashier (Payment Verifier)")),
                  DropdownMenuItem(value: 'viewer', child: Text("Viewer (Read Only)")),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInput)),
              ),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains('@')) return;
                Navigator.pop(dialogCtx);
                final success = await provider.addStaff(email, name: nameController.text.trim(), role: selectedRole);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? "Failed to add staff"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, RestaurantProvider provider, StaffMember member) {
    String selectedRole = member.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGlassDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
          title: Text("Change Role: ${member.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRole,
            dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            decoration: AppTheme.inputDecoration(
              isDark: isDark,
              labelText: "New Role",
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'owner', child: Text("Owner (Full Access)")),
              DropdownMenuItem(value: 'manager', child: Text("Manager (Operations)")),
              DropdownMenuItem(value: 'kitchen', child: Text("Kitchen (Cooking & Orders)")),
              DropdownMenuItem(value: 'cashier', child: Text("Cashier (Payment Verifier)")),
              DropdownMenuItem(value: 'viewer', child: Text("Viewer (Read Only)")),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => selectedRole = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusInput)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final success = await provider.updateStaffRole(member.id, selectedRole);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? "Failed to update role"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
}

