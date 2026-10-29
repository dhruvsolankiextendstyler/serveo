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
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? 'Serveo').toString(),
      slug: (json['slug'] ?? 'default').toString(),
      description: (json['description'] ?? '').toString(),
      logoUrl: (json['logoUrl'] ?? '').toString(),
      bannerUrl: (json['bannerUrl'] ?? '').toString(),
      addressStreet: (addr['street'] ?? '').toString(),
      addressCity: (addr['city'] ?? '').toString(),
      addressState: (addr['state'] ?? '').toString(),
      addressPostalCode: (addr['postalCode'] ?? '').toString(),
      contactPhone: (contact['phone'] ?? '').toString(),
      contactEmail: (contact['email'] ?? '').toString(),
      currency: (json['currency'] ?? 'INR').toString(),
      currencySymbol: (json['currencySymbol'] ?? '₹').toString(),
      timezone: (json['timezone'] ?? 'Asia/Kolkata').toString(),
      operatingDays: days,
      openingTime: openT,
      closingTime: closeT,
      isOrderAcceptancePaused: json['isOrderAcceptancePaused'] == true,
      pauseReason: (json['pauseReason'] ?? '').toString(),
      defaultEstimatedPrepTime: int.tryParse(json['defaultEstimatedPrepTime']?.toString() ?? '20') ?? 20,
      announcement: (disp['announcement'] ?? '').toString(),
      showPrepTime: disp['showPrepTime'] != false,
      showDietaryBadges: disp['showDietaryBadges'] != false,
      isOpen: avail['isOpen'] != false,
      availabilityStatus: (avail['status'] ?? (json['isOrderAcceptancePaused'] == true ? 'PAUSED' : 'OPEN')).toString(),
      availabilityReason: (avail['reason'] ?? '').toString(),
      operatingHoursFormatted: (avail['operatingHours'] ?? '$openT - $closeT').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'logoUrl': logoUrl,
    'address': {
      'street': addressStreet,
      'city': addressCity,
      'state': addressState,
      'postalCode': addressPostalCode,
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

class RestaurantProvider extends ChangeNotifier {
  RestaurantConfig _config = RestaurantConfig();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _qrDataUrl;
  String? _publicMenuUrl;

  RestaurantConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get qrDataUrl => _qrDataUrl;
  String? get publicMenuUrl => _publicMenuUrl;

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
      } else {
        debugPrint("[Serveo Restaurant] Server returned ${response.statusCode} for public info");
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
        // Refresh full settings
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
}

