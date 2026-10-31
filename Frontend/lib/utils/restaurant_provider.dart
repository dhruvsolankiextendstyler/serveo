import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class RestaurantConfig {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String logoUrl;
  final String bannerUrl;
  final String addressStreet;
  final String addressCity;
  final String addressState;
  final String addressPostalCode;
  final String contactPhone;
  final String contactEmail;
  final String currency;
  final String currencySymbol;
  final String timezone;
  final List<String> operatingDays;
  final String openingTime;
  final String closingTime;
  final bool isOrderAcceptancePaused;
  final String pauseReason;
  final int defaultEstimatedPrepTime;
  final String announcement;
  final bool showPrepTime;
  final bool showDietaryBadges;

  // Live availability
  final bool isOpen;
  final String availabilityStatus; // "OPEN" | "CLOSED" | "PAUSED"
  final String availabilityReason;
  final String operatingHoursFormatted;

  RestaurantConfig({
    this.id = '',
    this.name = 'Serveo',
    this.slug = 'default',
    this.description = 'Fresh meals & quick snacks ready for counter pickup',
    this.logoUrl = '',
    this.bannerUrl = '',
    this.addressStreet = 'Central Food Court',
    this.addressCity = 'Bengaluru',
    this.addressState = 'Karnataka',
    this.addressPostalCode = '560001',
    this.contactPhone = '+91 98765 43210',
    this.contactEmail = 'support@serveo.app',
    this.currency = 'INR',
    this.currencySymbol = '₹',
    this.timezone = 'Asia/Kolkata',
    this.operatingDays = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ],
    this.openingTime = '09:00',
    this.closingTime = '22:00',
    this.isOrderAcceptancePaused = false,
    this.pauseReason = '',
    this.defaultEstimatedPrepTime = 20,
    this.announcement = '',
    this.showPrepTime = true,
    this.showDietaryBadges = true,
    this.isOpen = true,
    this.availabilityStatus = 'OPEN',
    this.availabilityReason = 'Restaurant is open for orders.',
    this.operatingHoursFormatted = '09:00 - 22:00',
  });

  bool get canOrder => availabilityStatus == 'OPEN';
  bool get isPaused => availabilityStatus == 'PAUSED';
  bool get isClosed => availabilityStatus == 'CLOSED';

  factory RestaurantConfig.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] is Map ? json['address'] as Map : {};
    final contact = json['contact'] is Map ? json['contact'] as Map : {};
    final disp = json['displayPreferences'] is Map ? json['displayPreferences'] as Map : {};
    final avail = json['availability'] is Map ? json['availability'] as Map : {};

    final days = json['operatingDays'] is List
        ? (json['operatingDays'] as List).map((e) => e.toString()).toList()
        : [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday'
          ];

    final openT = (json['openingTime'] ?? '09:00').toString();
    final closeT = (json['closingTime'] ?? '22:00').toString();

    return RestaurantConfig(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: (json['name'] ?? 'Serveo').toString(),
      slug: (json['slug'] ?? 'default').toString(),
      description: (json['description'] ?? 'Fresh meals & quick snacks ready for counter pickup').toString(),
      logoUrl: (json['logoUrl'] ?? '').toString(),
      bannerUrl: (json['bannerUrl'] ?? '').toString(),
      addressStreet: (addr['street'] ?? json['addressStreet'] ?? 'Central Food Court').toString(),
      addressCity: (addr['city'] ?? json['addressCity'] ?? 'Bengaluru').toString(),
      addressState: (addr['state'] ?? json['addressState'] ?? 'Karnataka').toString(),
      addressPostalCode: (addr['postalCode'] ?? json['addressPostalCode'] ?? '560001').toString(),
      contactPhone: (contact['phone'] ?? json['contactPhone'] ?? '+91 98765 43210').toString(),
      contactEmail: (contact['email'] ?? json['contactEmail'] ?? 'support@serveo.app').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      currencySymbol: (json['currencySymbol'] ?? '₹').toString(),
      timezone: (json['timezone'] ?? 'Asia/Kolkata').toString(),
      operatingDays: days,
      openingTime: openT,
      closingTime: closeT,
      isOrderAcceptancePaused: json['isOrderAcceptancePaused'] == true,
      pauseReason: (json['pauseReason'] ?? '').toString(),
      defaultEstimatedPrepTime: int.tryParse(json['defaultEstimatedPrepTime']?.toString() ?? '20') ?? 20,
      announcement: (disp['announcement'] ?? json['announcement'] ?? '').toString(),
      showPrepTime: disp['showPrepTime'] != false,
      showDietaryBadges: disp['showDietaryBadges'] != false,
      isOpen: avail['isOpen'] != false,
      availabilityStatus: (avail['status'] ?? (json['isOrderAcceptancePaused'] == true ? 'PAUSED' : 'OPEN')).toString(),
      availabilityReason: (avail['reason'] ?? '').toString(),
      operatingHoursFormatted: (avail['hoursFormatted'] ?? '$openT - $closeT').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'slug': slug,
    'description': description,
    'logoUrl': logoUrl,
    'bannerUrl': bannerUrl,
    'address': {
      'street': addressStreet,
      'city': addressCity,
      'state': addressState,
      'postalCode': addressPostalCode,
      'country': 'India',
    },
    'contact': {
      'phone': contactPhone,
      'email': contactEmail,
    },
    'currency': currency,
    'currencySymbol': currencySymbol,
    'timezone': timezone,
    'operatingDays': operatingDays,
    'openingTime': openingTime,
    'closingTime': closingTime,
    'isOrderAcceptancePaused': isOrderAcceptancePaused,
    'pauseReason': pauseReason,
    'defaultEstimatedPrepTime': defaultEstimatedPrepTime,
    'displayPreferences': {
      'announcement': announcement,
      'showPrepTime': showPrepTime,
      'showDietaryBadges': showDietaryBadges,
    },
  };
}

class StaffMember {
  final String id;
  final String uid;
  final String email;
  final String name;
  final String role; // "owner" | "manager" | "kitchen" | "cashier" | "viewer"
  final bool isActive;
  final DateTime? addedAt;

  StaffMember({
    required this.id,
    this.uid = '',
    required this.email,
    required this.name,
    required this.role,
    this.isActive = true,
    this.addedAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'manager',
      isActive: json['isActive'] != false,
      addedAt: json['addedAt'] != null ? DateTime.tryParse(json['addedAt'].toString()) : null,
    );
  }
}

class SubscriptionInfo {
  final String planId;
  final String planName;
  final String planDescription;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? trialEndsAt;
  final bool isExpired;
  final bool inGracePeriod;
  final int activeItemsCurrent;
  final int activeItemsMax;
  final int staffCurrent;
  final int staffMax;
  final bool allowAdvancedAnalytics;
  final bool allowExport;
  final bool allowMarketingAndLoyalty;
  final bool allowCustomerRetentionAnalytics;

  SubscriptionInfo({
    required this.planId,
    required this.planName,
    required this.planDescription,
    required this.status,
    this.startDate,
    this.endDate,
    this.trialEndsAt,
    this.isExpired = false,
    this.inGracePeriod = false,
    required this.activeItemsCurrent,
    required this.activeItemsMax,
    required this.staffCurrent,
    required this.staffMax,
    this.allowAdvancedAnalytics = false,
    this.allowExport = false,
    this.allowMarketingAndLoyalty = false,
    this.allowCustomerRetentionAnalytics = false,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] is Map ? json['plan'] as Map : {};
    final sub = json['subscription'] is Map ? json['subscription'] as Map : {};
    final usage = json['usage'] is Map ? json['usage'] as Map : {};
    final activeItems = usage['activeMenuItems'] is Map ? usage['activeMenuItems'] as Map : {};
    final staff = usage['staffAccounts'] is Map ? usage['staffAccounts'] as Map : {};
    final features = plan['features'] is Map ? plan['features'] as Map : {};

    final planIdStr = (plan['id'] ?? 'starter').toString();
    return SubscriptionInfo(
      planId: planIdStr,
      planName: (plan['name'] ?? 'Starter').toString(),
      planDescription: (plan['description'] ?? '').toString(),
      status: (sub['status'] ?? 'active').toString(),
      startDate: sub['startDate'] != null ? DateTime.tryParse(sub['startDate'].toString()) : null,
      endDate: sub['endDate'] != null ? DateTime.tryParse(sub['endDate'].toString()) : null,
      trialEndsAt: sub['trialEndsAt'] != null ? DateTime.tryParse(sub['trialEndsAt'].toString()) : null,
      isExpired: sub['isExpired'] == true,
      inGracePeriod: sub['inGracePeriod'] == true,
      activeItemsCurrent: int.tryParse(activeItems['current']?.toString() ?? '0') ?? 0,
      activeItemsMax: int.tryParse(activeItems['max']?.toString() ?? '20') ?? 20,
      staffCurrent: int.tryParse(staff['current']?.toString() ?? '1') ?? 1,
      staffMax: int.tryParse(staff['max']?.toString() ?? '2') ?? 2,
      allowAdvancedAnalytics: features['advancedAnalytics'] == true,
      allowExport: features['exportData'] == true,
      allowMarketingAndLoyalty: features['marketingAndLoyalty'] == true || (planIdStr != 'starter' && planIdStr.isNotEmpty),
      allowCustomerRetentionAnalytics: features['customerRetentionAnalytics'] == true || (planIdStr != 'starter' && planIdStr.isNotEmpty),
    );
  }
}

class RestaurantProvider extends ChangeNotifier {
  RestaurantConfig _config = RestaurantConfig();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _qrDataUrl;
  String? _publicMenuUrl;

  List<StaffMember> _staff = [];
  String _currentRole = 'owner';
  SubscriptionInfo? _subscription;
  final List<Map<String, dynamic>> _auditLogs = [];

  RestaurantConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get qrDataUrl => _qrDataUrl;
  String? get publicMenuUrl => _publicMenuUrl;

  List<StaffMember> get staff => _staff;
  String get currentRole => _currentRole;
  bool get isOwner => _currentRole == 'owner';
  bool get isManager => _currentRole == 'manager' || _currentRole == 'owner';
  bool get isKitchen => _currentRole == 'kitchen';
  bool get isCashier => _currentRole == 'cashier';
  bool get isViewer => _currentRole == 'viewer';
  SubscriptionInfo? get subscription => _subscription;
  List<Map<String, dynamic>> get auditLogs => _auditLogs;

  /// Loads public restaurant information and availability for the customer app.
  Future<void> fetchPublicInfo({String identifier = 'default', http.Client? client}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/public/info?slug=$identifier");
      final response = await httpClient.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['restaurant'] != null) {
          _config = RestaurantConfig.fromJson(Map<String, dynamic>.from(decoded['restaurant']));
        }
      }
    } catch (e) {
      debugPrint("[Serveo Restaurant] Error fetching public info: $e");
    } finally {
      _isLoading = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
  }

  /// Loads full restaurant business settings for an authenticated restaurant administrator.
  Future<bool> fetchAdminSettings({http.Client? client, String? overrideToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/settings");
      final response = await httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['restaurant'] != null) {
          _config = RestaurantConfig.fromJson(Map<String, dynamic>.from(decoded['restaurant']));
          await fetchQrCode(client: httpClient, overrideToken: token);
          await fetchStaff(client: httpClient, overrideToken: token);
          await fetchSubscription(client: httpClient, overrideToken: token);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        _errorMessage = "Failed to load restaurant settings (HTTP ${response.statusCode})";
      }
    } catch (e) {
      _errorMessage = "Error connecting to restaurant server: $e";
      debugPrint("[Serveo Restaurant] fetchAdminSettings error: $e");
    } finally {
      _isLoading = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
    return false;
  }

  /// Loads staff members and resolved user role
  Future<bool> fetchStaff({http.Client? client, String? overrideToken}) async {
    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/staff");
      final response = await httpClient.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['staff'] is List) {
          _staff = (decoded['staff'] as List)
              .map((s) => StaffMember.fromJson(Map<String, dynamic>.from(s)))
              .toList();
          _currentRole = (decoded['currentRole'] ?? 'owner').toString();
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("[Serveo Restaurant] fetchStaff error: $e");
    } finally {
      if (client == null) httpClient.close();
    }
    return false;
  }

  /// Adds a new staff member with subscription capacity validation
  Future<bool> addStaff(String email, {String name = '', String role = 'manager', http.Client? client, String? overrideToken}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/staff");
      final response = await httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'name': name,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await fetchStaff(client: httpClient, overrideToken: token);
        await fetchSubscription(client: httpClient, overrideToken: token);
        return true;
      } else {
        _errorMessage = decoded is Map ? (decoded['message'] ?? decoded['error'] ?? "Failed to add staff") : "Failed to add staff";
      }
    } catch (e) {
      _errorMessage = "Network error adding staff: $e";
    } finally {
      _isSaving = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
    return false;
  }

  /// Updates an existing staff member's role (enforcing last-owner guard on backend)
  Future<bool> updateStaffRole(String staffId, String role, {bool? isActive, http.Client? client, String? overrideToken}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/staff/$staffId/role");
      final response = await httpClient.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'role': role,
          if (isActive != null) 'isActive': isActive,
        }),
      ).timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await fetchStaff(client: httpClient, overrideToken: token);
        return true;
      } else {
        _errorMessage = decoded is Map ? (decoded['message'] ?? decoded['error'] ?? "Failed to update role") : "Failed to update role";
      }
    } catch (e) {
      _errorMessage = "Network error updating staff role: $e";
    } finally {
      _isSaving = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
    return false;
  }

  /// Removes a staff member (with last-owner guard)
  Future<bool> removeStaff(String staffId, {http.Client? client, String? overrideToken}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/staff/$staffId");
      final response = await httpClient.delete(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await fetchStaff(client: httpClient, overrideToken: token);
        await fetchSubscription(client: httpClient, overrideToken: token);
        return true;
      } else {
        _errorMessage = decoded is Map ? (decoded['message'] ?? decoded['error'] ?? "Failed to remove staff") : "Failed to remove staff";
      }
    } catch (e) {
      _errorMessage = "Network error removing staff: $e";
    } finally {
      _isSaving = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
    return false;
  }

  /// Fetches subscription plan information, limits, and usage
  Future<bool> fetchSubscription({http.Client? client, String? overrideToken}) async {
    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/subscription");
      final response = await httpClient.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          _subscription = SubscriptionInfo.fromJson(Map<String, dynamic>.from(decoded));
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("[Serveo Restaurant] fetchSubscription error: $e");
    } finally {
      if (client == null) httpClient.close();
    }
    return false;
  }

  /// Updates business configuration settings on the backend.
  Future<bool> updateSettings(Map<String, dynamic> updates, {http.Client? client, String? overrideToken}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/settings");
      final response = await httpClient.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map && decoded['restaurant'] != null) {
        _config = RestaurantConfig.fromJson(Map<String, dynamic>.from(decoded['restaurant']));
        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = decoded is Map ? (decoded['error'] ?? "Failed to save settings") : "Failed to save settings";
      }
    } catch (e) {
      _errorMessage = "Unable to save settings: $e";
      debugPrint("[Serveo Restaurant] updateSettings error: $e");
    } finally {
      _isSaving = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
    return false;
  }

  /// Quick toggle for pausing/resuming order acceptance.
  Future<bool> togglePauseOrders(bool paused, {String reason = '', http.Client? client, String? overrideToken}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/pause-status");
      final response = await httpClient.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'isOrderAcceptancePaused': paused,
          'pauseReason': reason,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchAdminSettings(client: httpClient, overrideToken: token);
        return true;
      }
    } catch (e) {
      _errorMessage = "Failed to update pause status: $e";
      debugPrint("[Serveo Restaurant] togglePauseOrders error: $e");
    } finally {
      _isSaving = false;
      if (client == null) httpClient.close();
      notifyListeners();
    }
    return false;
  }

  /// Fetches public menu QR code and URL.
  Future<void> fetchQrCode({http.Client? client, String? overrideToken}) async {
    final httpClient = client ?? http.Client();
    try {
      String? token = overrideToken;
      if (token == null) {
        final user = FirebaseAuth.instance.currentUser;
        token = await user?.getIdToken();
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/admin/qr");
      final response = await httpClient.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          _qrDataUrl = decoded['qrDataUrl']?.toString();
          _publicMenuUrl = decoded['menuUrl']?.toString();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("[Serveo Restaurant] fetchQrCode error: $e");
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Sets config directly (useful for tests or mocking)
  void setConfigForTest(RestaurantConfig config) {
    _config = config;
    notifyListeners();
  }

  /// Sets role directly for unit/widget testing
  void setRoleForTest(String role) {
    _currentRole = role;
    notifyListeners();
  }

  /// Sets subscription directly for testing
  void setSubscriptionForTest(SubscriptionInfo sub) {
    _subscription = sub;
    notifyListeners();
  }

  /// Sets staff list directly for testing
  void setStaffForTest(List<StaffMember> staffList) {
    _staff = staffList;
    notifyListeners();
  }
}
