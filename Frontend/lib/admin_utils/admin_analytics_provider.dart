import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

// --- MODELS ---

class SelectedRangeInfo {
  final String timeframe;
  final String label;
  final DateTime start;
  final DateTime end;
  final bool isSingleDay;
  final String timezone;

  SelectedRangeInfo({
    required this.timeframe,
    required this.label,
    required this.start,
    required this.end,
    required this.isSingleDay,
    required this.timezone,
  });

  factory SelectedRangeInfo.fromJson(Map<String, dynamic> json) {
    return SelectedRangeInfo(
      timeframe: json['timeframe'] ?? 'today',
      label: json['label'] ?? 'Today',
      start: DateTime.tryParse(json['start'] ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end'] ?? '') ?? DateTime.now(),
      isSingleDay: json['isSingleDay'] ?? false,
      timezone: json['timezone'] ?? 'Asia/Kolkata',
    );
  }
}

class MetricComparison {
  final double? grossSalesChangePct;
  final double? totalOrdersChangePct;
  final double? completedOrdersChangePct;
  final double? aovChangePct;

  MetricComparison({
    this.grossSalesChangePct,
    this.totalOrdersChangePct,
    this.completedOrdersChangePct,
    this.aovChangePct,
  });

  factory MetricComparison.fromJson(Map<String, dynamic> json) {
    return MetricComparison(
      grossSalesChangePct: json['grossSalesChangePct'] != null ? (json['grossSalesChangePct'] as num).toDouble() : null,
      totalOrdersChangePct: json['totalOrdersChangePct'] != null ? (json['totalOrdersChangePct'] as num).toDouble() : null,
      completedOrdersChangePct: json['completedOrdersChangePct'] != null ? (json['completedOrdersChangePct'] as num).toDouble() : null,
      aovChangePct: json['aovChangePct'] != null ? (json['aovChangePct'] as num).toDouble() : null,
    );
  }
}

class AnalyticsOverview {
  final SelectedRangeInfo selectedRange;
  final int grossSales;
  final int netSales;
  final String netSalesNote;
  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final int averageOrderValue;
  final int pendingUpiVerifications;
  final MetricComparison comparison;
  final String previousLabel;

  AnalyticsOverview({
    required this.selectedRange,
    required this.grossSales,
    required this.netSales,
    required this.netSalesNote,
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.averageOrderValue,
    required this.pendingUpiVerifications,
    required this.comparison,
    required this.previousLabel,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map ? (json['summary'] as Map) : const <String, dynamic>{};
    final prev = json['previousPeriod'] is Map ? (json['previousPeriod'] as Map) : const <String, dynamic>{};
    final comp = json['comparison'] is Map ? Map<String, dynamic>.from(json['comparison']) : <String, dynamic>{};
    final range = json['selectedRange'] is Map ? Map<String, dynamic>.from(json['selectedRange']) : <String, dynamic>{};

    return AnalyticsOverview(
      selectedRange: SelectedRangeInfo.fromJson(range),
      grossSales: (summary['grossSales'] as num?)?.toInt() ?? 0,
      netSales: (summary['netSales'] as num?)?.toInt() ?? 0,
      netSalesNote: summary['netSalesNote'] ?? '',
      totalOrders: (summary['totalOrders'] as num?)?.toInt() ?? 0,
      completedOrders: (summary['completedOrders'] as num?)?.toInt() ?? 0,
      pendingOrders: (summary['pendingOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (summary['cancelledOrders'] as num?)?.toInt() ?? 0,
      averageOrderValue: (summary['averageOrderValue'] as num?)?.toInt() ?? 0,
      pendingUpiVerifications: (summary['pendingUpiVerifications'] as num?)?.toInt() ?? 0,
      comparison: MetricComparison.fromJson(comp),
      previousLabel: prev['label'] ?? 'Previous Period',
    );
  }
}

class SalesTimelinePoint {
  final dynamic key;
  final String label;
  final int revenue;
  final int ordersCount;
  final int paidOrdersCount;

  SalesTimelinePoint({
    required this.key,
    required this.label,
    required this.revenue,
    required this.ordersCount,
    required this.paidOrdersCount,
  });

  factory SalesTimelinePoint.fromJson(Map<String, dynamic> json) {
    return SalesTimelinePoint(
      key: json['key'],
      label: json['label'] ?? '',
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      ordersCount: (json['ordersCount'] as num?)?.toInt() ?? 0,
      paidOrdersCount: (json['paidOrdersCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class SalesTimeline {
  final String grouping;
  final String rangeLabel;
  final int totalRevenue;
  final int totalOrders;
  final List<SalesTimelinePoint> timeline;

  SalesTimeline({
    required this.grouping,
    required this.rangeLabel,
    required this.totalRevenue,
    required this.totalOrders,
    required this.timeline,
  });

  factory SalesTimeline.fromJson(Map<String, dynamic> json) {
    final rawList = json['timeline'] as List? ?? [];
    return SalesTimeline(
      grouping: json['grouping'] ?? 'daily',
      rangeLabel: json['rangeLabel'] ?? '',
      totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      timeline: rawList.map((e) => SalesTimelinePoint.fromJson(e)).toList(),
    );
  }
}

class OrderPerformance {
  final int totalOrders;
  final Map<String, int> statusBreakdown;
  final double completionRate;
  final double cancellationRate;
  final double? averagePrepTimeMinutes;
  final String prepTimeNote;
  final Map<String, dynamic> paymentDistribution;

  OrderPerformance({
    required this.totalOrders,
    required this.statusBreakdown,
    required this.completionRate,
    required this.cancellationRate,
    required this.averagePrepTimeMinutes,
    required this.prepTimeNote,
    required this.paymentDistribution,
  });

  factory OrderPerformance.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['statusBreakdown'] as Map<String, dynamic>? ?? {};
    final statusMap = <String, int>{};
    rawStatus.forEach((k, v) => statusMap[k] = (v as num?)?.toInt() ?? 0);

    return OrderPerformance(
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      statusBreakdown: statusMap,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0.0,
      averagePrepTimeMinutes: json['averagePrepTimeMinutes'] != null
          ? (json['averagePrepTimeMinutes'] as num).toDouble()
          : null,
      prepTimeNote: json['prepTimeNote'] ?? '',
      paymentDistribution: json['paymentDistribution'] ?? {},
    );
  }
}

class PopularItem {
  final String itemName;
  final String? itemId;
  final String category;
  final int quantitySold;
  final int salesValue;
  final int ordersCount;

  PopularItem({
    required this.itemName,
    this.itemId,
    required this.category,
    required this.quantitySold,
    required this.salesValue,
    required this.ordersCount,
  });

  factory PopularItem.fromJson(Map<String, dynamic> json) {
    return PopularItem(
      itemName: json['itemName'] ?? 'Unknown Item',
      itemId: json['itemId']?.toString(),
      category: json['category'] ?? 'General',
      quantitySold: (json['quantitySold'] as num?)?.toInt() ?? 0,
      salesValue: (json['salesValue'] as num?)?.toInt() ?? 0,
      ordersCount: (json['ordersCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class UnderperformingItem {
  final String? itemId;
  final String itemName;
  final String category;
  final int quantitySold;
  final int salesValue;
  final bool isAvailable;
  final String status;
  final String statusLabel;

  UnderperformingItem({
    this.itemId,
    required this.itemName,
    required this.category,
    required this.quantitySold,
    required this.salesValue,
    required this.isAvailable,
    required this.status,
    required this.statusLabel,
  });

  factory UnderperformingItem.fromJson(Map<String, dynamic> json) {
    return UnderperformingItem(
      itemId: json['itemId']?.toString(),
      itemName: json['itemName'] ?? 'Unknown Item',
      category: json['category'] ?? 'General',
      quantitySold: (json['quantitySold'] as num?)?.toInt() ?? 0,
      salesValue: (json['salesValue'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] ?? true,
      status: json['status'] ?? 'zero_sales',
      statusLabel: json['statusLabel'] ?? 'Zero Sales',
    );
  }
}

class ItemInsights {
  final int totalUniqueItemsSold;
  final List<PopularItem> popularItems;
  final List<UnderperformingItem> underperformingItems;

  ItemInsights({
    required this.totalUniqueItemsSold,
    required this.popularItems,
    required this.underperformingItems,
  });

  factory ItemInsights.fromJson(Map<String, dynamic> json) {
    final popRaw = json['popularItems'] as List? ?? [];
    final underRaw = json['underperformingItems'] as List? ?? [];
    return ItemInsights(
      totalUniqueItemsSold: (json['totalUniqueItemsSold'] as num?)?.toInt() ?? 0,
      popularItems: popRaw.map((e) => PopularItem.fromJson(e)).toList(),
      underperformingItems: underRaw.map((e) => UnderperformingItem.fromJson(e)).toList(),
    );
  }
}

class PeakHourPoint {
  final int hour;
  final String label;
  final int ordersCount;
  final int volume;

  PeakHourPoint({required this.hour, required this.label, required this.ordersCount, required this.volume});

  factory PeakHourPoint.fromJson(Map<String, dynamic> json) {
    return PeakHourPoint(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      label: json['label'] ?? '',
      ordersCount: (json['ordersCount'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
    );
  }
}

class PeakDayPoint {
  final int dayOfWeek;
  final String dayName;
  final int ordersCount;
  final int volume;

  PeakDayPoint({required this.dayOfWeek, required this.dayName, required this.ordersCount, required this.volume});

  factory PeakDayPoint.fromJson(Map<String, dynamic> json) {
    return PeakDayPoint(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      dayName: json['dayName'] ?? '',
      ordersCount: (json['ordersCount'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
    );
  }
}

class PeakHoursData {
  final List<PeakHourPoint> hourlyVolume;
  final List<PeakDayPoint> dayOfWeekVolume;
  final PeakHourPoint? peakHour;
  final PeakDayPoint? peakDay;

  PeakHoursData({
    required this.hourlyVolume,
    required this.dayOfWeekVolume,
    this.peakHour,
    this.peakDay,
  });

  factory PeakHoursData.fromJson(Map<String, dynamic> json) {
    final hours = (json['hourlyVolume'] as List? ?? []).map((e) => PeakHourPoint.fromJson(e)).toList();
    final days = (json['dayOfWeekVolume'] as List? ?? []).map((e) => PeakDayPoint.fromJson(e)).toList();
    return PeakHoursData(
      hourlyVolume: hours,
      dayOfWeekVolume: days,
      peakHour: json['peakHour'] != null ? PeakHourPoint.fromJson(json['peakHour']) : null,
      peakDay: json['peakDay'] != null ? PeakDayPoint.fromJson(json['peakDay']) : null,
    );
  }
}

class PaymentMethodStats {
  final int totalOrders;
  final int totalAmount;
  final int verifiedCount;
  final int verifiedAmount;
  final int pendingVerificationCount;
  final int pendingVerificationAmount;
  final int rejectedCount;
  final int rejectedAmount;

  PaymentMethodStats({
    required this.totalOrders,
    required this.totalAmount,
    this.verifiedCount = 0,
    this.verifiedAmount = 0,
    this.pendingVerificationCount = 0,
    this.pendingVerificationAmount = 0,
    this.rejectedCount = 0,
    this.rejectedAmount = 0,
  });

  factory PaymentMethodStats.fromJson(Map<String, dynamic> json) {
    return PaymentMethodStats(
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toInt() ?? 0,
      verifiedCount: (json['verifiedCount'] as num?)?.toInt() ?? 0,
      verifiedAmount: (json['verifiedAmount'] as num?)?.toInt() ?? 0,
      pendingVerificationCount: (json['pendingVerificationCount'] as num?)?.toInt() ?? 0,
      pendingVerificationAmount: (json['pendingVerificationAmount'] as num?)?.toInt() ?? 0,
      rejectedCount: (json['rejectedCount'] as num?)?.toInt() ?? 0,
      rejectedAmount: (json['rejectedAmount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaymentAnalytics {
  final int grandTotalOrders;
  final int verifiedRevenue;
  final PaymentMethodStats upi;
  final PaymentMethodStats cod;
  final PaymentMethodStats card;
  final double upiOrderPct;
  final double codOrderPct;
  final double cardOrderPct;

  PaymentAnalytics({
    required this.grandTotalOrders,
    required this.verifiedRevenue,
    required this.upi,
    required this.cod,
    required this.card,
    required this.upiOrderPct,
    required this.codOrderPct,
    required this.cardOrderPct,
  });

  factory PaymentAnalytics.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] ?? {};
    final dist = json['distribution'] ?? {};
    return PaymentAnalytics(
      grandTotalOrders: (summary['grandTotalOrders'] as num?)?.toInt() ?? 0,
      verifiedRevenue: (summary['verifiedRevenue'] as num?)?.toInt() ?? 0,
      upi: PaymentMethodStats.fromJson(json['upi'] ?? {}),
      cod: PaymentMethodStats.fromJson(json['cod'] ?? {}),
      card: PaymentMethodStats.fromJson(json['card'] ?? {}),
      upiOrderPct: (dist['upiOrderPct'] as num?)?.toDouble() ?? 0.0,
      codOrderPct: (dist['codOrderPct'] as num?)?.toDouble() ?? 0.0,
      cardOrderPct: (dist['cardOrderPct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Cached bundle to avoid duplicate network fetches during widget rebuilds
class _CachedBundle {
  final AnalyticsOverview overview;
  final SalesTimeline salesTimeline;
  final OrderPerformance orderPerformance;
  final ItemInsights itemInsights;
  final PeakHoursData peakHours;
  final PaymentAnalytics paymentAnalytics;
  final DateTime cachedAt;

  _CachedBundle({
    required this.overview,
    required this.salesTimeline,
    required this.orderPerformance,
    required this.itemInsights,
    required this.peakHours,
    required this.paymentAnalytics,
    required this.cachedAt,
  });

  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes >= 3;
}

// --- PROVIDER ---

class AdminAnalyticsProvider extends ChangeNotifier {
  String _selectedTimeframe = 'today';
  DateTimeRange? _customRange;
  String _itemSortBy = 'quantity';

  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  AnalyticsOverview? _overview;
  SalesTimeline? _salesTimeline;
  OrderPerformance? _orderPerformance;
  ItemInsights? _itemInsights;
  PeakHoursData? _peakHours;
  PaymentAnalytics? _paymentAnalytics;

  final http.Client? customClient;

  AdminAnalyticsProvider({this.customClient});

  // Stale-request prevention ID
  int _activeRequestId = 0;

  // In-memory cache by query key
  final Map<String, _CachedBundle> _cache = {};

  // Getters
  String get selectedTimeframe => _selectedTimeframe;
  DateTimeRange? get customRange => _customRange;
  String get itemSortBy => _itemSortBy;
  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;
  String? get errorMessage => _errorMessage;

  AnalyticsOverview? get overview => _overview;
  SalesTimeline? get salesTimeline => _salesTimeline;
  OrderPerformance? get orderPerformance => _orderPerformance;
  ItemInsights? get itemInsights => _itemInsights;
  PeakHoursData? get peakHours => _peakHours;
  PaymentAnalytics? get paymentAnalytics => _paymentAnalytics;

  String _buildCacheKey(String tf, DateTimeRange? cr, String sortBy) {
    if (tf == 'custom' && cr != null) {
      final s = "${cr.start.year}-${cr.start.month.toString().padLeft(2, '0')}-${cr.start.day.toString().padLeft(2, '0')}";
      final e = "${cr.end.year}-${cr.end.month.toString().padLeft(2, '0')}-${cr.end.day.toString().padLeft(2, '0')}";
      return "custom_${s}_${e}_$sortBy";
    }
    return "${tf}_$sortBy";
  }

  void setTimeframe(String timeframe, {DateTimeRange? customRange}) {
    if (_selectedTimeframe == timeframe && _customRange == customRange) return;
    _selectedTimeframe = timeframe;
    _customRange = customRange;
    loadAnalytics();
  }

  void setItemSortBy(String sortBy) {
    if (_itemSortBy == sortBy) return;
    _itemSortBy = sortBy;
    loadAnalytics();
  }

  Future<void> refresh() async {
    final key = _buildCacheKey(_selectedTimeframe, _customRange, _itemSortBy);
    _cache.remove(key);
    await loadAnalytics();
  }

  Future<void> loadAnalytics([http.Client? client]) async {
    final key = _buildCacheKey(_selectedTimeframe, _customRange, _itemSortBy);

    // 1. Serve from in-memory cache if available and fresh
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      _overview = cached.overview;
      _salesTimeline = cached.salesTimeline;
      _orderPerformance = cached.orderPerformance;
      _itemInsights = cached.itemInsights;
      _peakHours = cached.peakHours;
      _paymentAnalytics = cached.paymentAnalytics;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final requestId = ++_activeRequestId;
    final activeClient = client ?? customClient ?? http.Client();

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

      String queryParams = "timeframe=$_selectedTimeframe&sortBy=$_itemSortBy";
      if (_selectedTimeframe == 'custom' && _customRange != null) {
        final s = "${_customRange!.start.year}-${_customRange!.start.month.toString().padLeft(2, '0')}-${_customRange!.start.day.toString().padLeft(2, '0')}";
        final e = "${_customRange!.end.year}-${_customRange!.end.month.toString().padLeft(2, '0')}-${_customRange!.end.day.toString().padLeft(2, '0')}";
        queryParams += "&startDate=$s&endDate=$e";
      }

      // Fetch overview, sales, orders, items, peak-hours, and payments concurrently
      final baseUrl = ApiConfig.baseUrl;

      // Try /order/analytics first; if 404, fallback to /admin/analytics
      String basePath = "$baseUrl/order/analytics";
      var results = await Future.wait([
        activeClient.get(Uri.parse("$basePath/overview?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
        activeClient.get(Uri.parse("$basePath/sales?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
        activeClient.get(Uri.parse("$basePath/orders?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
        activeClient.get(Uri.parse("$basePath/items?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
        activeClient.get(Uri.parse("$basePath/peak-hours?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
        activeClient.get(Uri.parse("$basePath/payments?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
      ]);

      // If the primary path returns 404, check if mounted under /admin/analytics
      if (results[0].statusCode == 404) {
        final altBasePath = "$baseUrl/admin/analytics";
        final altResults = await Future.wait([
          activeClient.get(Uri.parse("$altBasePath/overview?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
          activeClient.get(Uri.parse("$altBasePath/sales?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
          activeClient.get(Uri.parse("$altBasePath/orders?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
          activeClient.get(Uri.parse("$altBasePath/items?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
          activeClient.get(Uri.parse("$altBasePath/peak-hours?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
          activeClient.get(Uri.parse("$altBasePath/payments?$queryParams"), headers: headers).timeout(const Duration(seconds: 15)),
        ]);
        if (altResults[0].statusCode != 404) {
          results = altResults;
          basePath = altBasePath;
        }
      }

      // Check for stale response
      if (requestId != _activeRequestId) return;

      // Safely parse each endpoint response with HTML detection and status checks
      final overviewData = AnalyticsOverview.fromJson(_safeParseJsonResponse(results[0], "overview"));
      final salesData = SalesTimeline.fromJson(_safeParseJsonResponse(results[1], "sales"));
      final ordersData = OrderPerformance.fromJson(_safeParseJsonResponse(results[2], "orders"));
      final itemsData = ItemInsights.fromJson(_safeParseJsonResponse(results[3], "items"));
      final peakHoursData = PeakHoursData.fromJson(_safeParseJsonResponse(results[4], "peak-hours"));
      final paymentsData = PaymentAnalytics.fromJson(_safeParseJsonResponse(results[5], "payments"));

      _overview = overviewData;
      _salesTimeline = salesData;
      _orderPerformance = ordersData;
      _itemInsights = itemsData;
      _peakHours = peakHoursData;
      _paymentAnalytics = paymentsData;
      _errorMessage = null;

      // Save to cache
      _cache[key] = _CachedBundle(
        overview: overviewData,
        salesTimeline: salesData,
        orderPerformance: ordersData,
        itemInsights: itemsData,
        peakHours: peakHoursData,
        paymentAnalytics: paymentsData,
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      if (requestId == _activeRequestId) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
      }
    } finally {
      if (requestId == _activeRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Exports sanitized CSV report and copies to clipboard with user feedback
  Future<void> exportCsv(BuildContext context) async {
    _isExporting = true;
    notifyListeners();

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = {
        if (token != null) "Authorization": "Bearer $token",
      };

      String queryParams = "timeframe=$_selectedTimeframe";
      if (_selectedTimeframe == 'custom' && _customRange != null) {
        final s = "${_customRange!.start.year}-${_customRange!.start.month.toString().padLeft(2, '0')}-${_customRange!.start.day.toString().padLeft(2, '0')}";
        final e = "${_customRange!.end.year}-${_customRange!.end.month.toString().padLeft(2, '0')}-${_customRange!.end.day.toString().padLeft(2, '0')}";
        queryParams += "&startDate=$s&endDate=$e";
      }

      final activeClient = customClient ?? http.Client();
      var res = await activeClient.get(
        Uri.parse("${ApiConfig.baseUrl}/order/analytics/export?$queryParams"),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 404) {
        final altRes = await activeClient.get(
          Uri.parse("${ApiConfig.baseUrl}/admin/analytics/export?$queryParams"),
          headers: headers,
        ).timeout(const Duration(seconds: 15));
        if (altRes.statusCode != 404) {
          res = altRes;
        }
      }

      final contentType = res.headers['content-type']?.toLowerCase() ?? '';
      final bodyTrimmed = res.body.trim();
      final isHtml = contentType.contains('text/html') ||
          bodyTrimmed.startsWith('<!DOCTYPE') ||
          bodyTrimmed.startsWith('<!doctype') ||
          bodyTrimmed.startsWith('<html');

      if (res.statusCode == 200 && !isHtml) {
        final csvText = res.body;
        await Clipboard.setData(ClipboardData(text: csvText));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Analytics CSV copied to clipboard! Paste it into Excel or Google Sheets.",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E1E),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (isHtml) {
          debugPrint("[Serveo Analytics] CSV Export returned HTML (HTTP ${res.statusCode}).");
          throw Exception("Unable to load CSV export. The server returned an unexpected response.");
        }
        throw Exception("Failed to generate CSV export (HTTP ${res.statusCode})");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("CSV Export Error: ${e.toString().replaceFirst("Exception: ", "")}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Safely decodes a JSON HTTP response, gracefully detecting and handling HTML/error responses
  /// without triggering FormatSyntaxError / FormatException crashes.
  static Map<String, dynamic> _safeParseJsonResponse(http.Response res, String endpointName) {
    final contentType = res.headers['content-type']?.toLowerCase() ?? '';
    final bodyTrimmed = res.body.trim();
    final isHtml = contentType.contains('text/html') ||
        bodyTrimmed.startsWith('<!DOCTYPE') ||
        bodyTrimmed.startsWith('<!doctype') ||
        bodyTrimmed.startsWith('<html');

    if (isHtml) {
      debugPrint(
        "[Serveo Analytics] Endpoint '$endpointName' returned HTML instead of JSON (HTTP ${res.statusCode}). "
        "Snippet: ${bodyTrimmed.length > 100 ? bodyTrimmed.substring(0, 100) : bodyTrimmed}",
      );
      throw Exception(
        "Unable to load analytics. The server returned an unexpected response. Please try again or contact support.",
      );
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception("Unauthorized: Admin privileges required.");
    }

    if (res.statusCode >= 400) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final err = decoded['error'] ?? decoded['message'];
          if (err != null) throw Exception(err.toString());
        }
      } catch (e) {
        if (e is! FormatException) rethrow;
      }
      throw Exception("Failed to load analytics data (HTTP ${res.statusCode})");
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception("Unexpected data structure received from '$endpointName'.");
    } catch (e) {
      if (e is FormatException) {
        debugPrint("[Serveo Analytics] JSON parsing failed for '$endpointName': $e");
        throw Exception(
          "Unable to load analytics. The server returned an unexpected response. Please try again or contact support.",
        );
      }
      rethrow;
    }
  }
}
