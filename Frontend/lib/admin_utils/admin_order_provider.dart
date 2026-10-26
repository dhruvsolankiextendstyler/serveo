import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import '../utils/api_config.dart';
import 'admin_order.dart';

class AdminOrderProvider extends ChangeNotifier {
  List<AdminOrder> _orders = [];
  bool _isLoading = false;
  bool _isPolling = false;
  DateTime? _lastUpdated;
  Timer? _pollingTimer;

  // Track notified and dismissed orders to prevent repeated floating alerts
  final Set<String> _notifiedOrderIds = {};
  final Set<String> _dismissedOrderIds = {};
  AdminOrder? _pendingAlertOrder;

  List<AdminOrder> get orders => _orders;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;
  AdminOrder? get pendingAlertOrder => _pendingAlertOrder;

  // Outstanding verification requests
  List<AdminOrder> get pendingVerificationOrders =>
      _orders.where((o) => o.isUpi && o.isAwaitingVerification).toList();

  // Filtered Lists
  List<AdminOrder> get liveOrders =>
      _orders.where((o) => o.status != 'Completed' && o.status != 'Ready' && o.status != "Collected" && o.status != 'Cancelled').toList();
  List<AdminOrder> get historyOrders =>
      _orders.where((o) => o.status == 'Completed' || o.status == 'Ready' || o.status == "Collected" || o.status == 'Cancelled').toList();

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchOrdersSilent();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dismissAlert(String orderId) {
    _dismissedOrderIds.add(orderId);
    if (_pendingAlertOrder?.id == orderId) {
      _pendingAlertOrder = null;
    }
    notifyListeners();
  }

  void clearAlert() {
    _pendingAlertOrder = null;
    notifyListeners();
  }

  void _checkForPendingVerificationAlerts() {
    final pending = pendingVerificationOrders;

    // Check if current alert is still pending
    if (_pendingAlertOrder != null) {
      final stillPending = pending.any((o) => o.id == _pendingAlertOrder!.id);
      if (!stillPending) {
        _pendingAlertOrder = null;
      }
    }

    // Look for new unnotified pending verification order
    if (_pendingAlertOrder == null) {
      for (final o in pending) {
        if (!_notifiedOrderIds.contains(o.id) && !_dismissedOrderIds.contains(o.id)) {
          _notifiedOrderIds.add(o.id);
          _pendingAlertOrder = o;
          break;
        }
      }
    }
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await get(
        Uri.parse("${ApiConfig.baseUrl}/order/"),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] is List) {
          final List<dynamic> data = decoded['message'];
          _orders = data.map((json) => AdminOrder.fromJson(json)).toList();
          _lastUpdated = DateTime.now();
          _checkForPendingVerificationAlerts();
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
    if (_isPolling) return;
    _isPolling = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await get(
        Uri.parse("${ApiConfig.baseUrl}/order/"),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] is List) {
          final List<dynamic> data = decoded['message'];
          final updatedOrders = data.map((json) => AdminOrder.fromJson(json)).toList();

          _orders = updatedOrders;
          _lastUpdated = DateTime.now();
          _checkForPendingVerificationAlerts();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Silent polling error: $e");
    } finally {
      _isPolling = false;
    }
  }

  Future<bool> verifyPayment(String orderId, bool verified) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await patch(
        Uri.parse("${ApiConfig.baseUrl}/order/verify-payment"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "orderId": orderId,
          "verified": verified,
        }),
      );

      if (response.statusCode == 200) {
        final int index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          if (verified) {
            _orders[index].status = "Preparing";
            _orders[index].paymentStatus = "Verified";
            _orders[index].paymentVerifiedAt = DateTime.now();
            _orders[index].verifiedBy = user?.email ?? "Admin";
          } else {
            _orders[index].status = "Payment Rejected";
            _orders[index].paymentStatus = "Rejected";
            _orders[index].paymentVerifiedAt = DateTime.now();
            _orders[index].verifiedBy = user?.email ?? "Admin";
          }
        }
        if (_pendingAlertOrder?.id == orderId) {
          _pendingAlertOrder = null;
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("verifyPayment error: $e");
    }
    return false;
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    int index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();

        await patch(
          Uri.parse("${ApiConfig.baseUrl}/order/updatestatus"),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
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

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}