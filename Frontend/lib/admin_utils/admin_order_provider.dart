import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import '../utils/api_config.dart';
import 'admin_order.dart';

class AdminOrderProvider extends ChangeNotifier {
  List<AdminOrder> _orders = [];
  bool _isLoading = false;
  bool _isPolling = false;
  DateTime? _lastUpdated;

  List<AdminOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  // Filtered Lists
  List<AdminOrder> get liveOrders => _orders.where((o) => o.status != 'Completed' && o.status != "Collected").toList();
  List<AdminOrder> get historyOrders => _orders.where((o) => o.status == 'Completed' || o.status == "Collected").toList();

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await get(
        Uri.parse("${ApiConfig.baseUrl}/order/"),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] is List) {
          final List<dynamic> data = decoded['message'];
          _orders = data.map((json) => AdminOrder.fromJson(json)).toList();
          _lastUpdated = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint("fetchOrders error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOrdersSilent() async {
    // Prevent overlapping requests if a previous cycle is still executing
    if (_isPolling) return;
    _isPolling = true;

    try {
      final response = await get(
        Uri.parse("${ApiConfig.baseUrl}/order/"),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] is List) {
          final List<dynamic> data = decoded['message'];
          final updatedOrders = data.map((json) => AdminOrder.fromJson(json)).toList();

          // Update orders list smoothly
          _orders = updatedOrders;
          _lastUpdated = DateTime.now();
          notifyListeners();
        }
      }
    } catch (e) {
      // Gracefully retain existing orders on network hiccups and retry on the next cycle
      debugPrint("Silent polling error: $e");
    } finally {
      _isPolling = false;
    }
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    int index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      try {
        await patch(
          Uri.parse("${ApiConfig.baseUrl}/order/updatestatus"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "id": orderId,
            "newStatus": newStatus,
          }),
        );
        _orders[index].status = newStatus;
        notifyListeners();
      } catch (e) {
        debugPrint("updateStatus error: $e");
      }
    }
  }
}