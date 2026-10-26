import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'api_config.dart';


class OrderProvider extends ChangeNotifier{
  final List<Item> _orderItems = [];

  List<Item> get orderItems => _orderItems;

  int getItemQuantity(String itemId) {
    int index = _orderItems.indexWhere((it) => it.itemId == itemId);
    return index != -1 ? _orderItems[index].quantity : 0;
  }

  void addToCart(Item item, [BuildContext? context]){
    int index = _orderItems.indexWhere((it) => it.itemId == item.itemId);
    if (index != -1) {
      // 2. Check Quantity Limit (Max 3)
      if (_orderItems[index].quantity < 3) {
        _orderItems[index].quantity++;
      } else {
        if (context != null) showToast("Maximum 3 of the same item allowed!", context);
        return;
      }
    } else {
      // 3. Check Total Unique Items Limit (Max 5)
      if (_orderItems.length < 5) {
        _orderItems.add(item..quantity = 1);
      } else {
        if (context != null) showToast("You can only order up to 5 different items!", context);
        return;
      }
    }
    notifyListeners();
  }

  void decrementQuantity(Item item) {
    int index = _orderItems.indexWhere((it) => it.itemId == item.itemId);
    if (index != -1) {
      if (_orderItems[index].quantity > 1) {
        _orderItems[index].quantity -= 1;
      } else {
        _orderItems.removeAt(index); // Remove item if it hits 0
      }
      notifyListeners();
    }
  }

  int getTotal(){
    return _orderItems.fold(0, (total, item) => total + (item.itemPrice * item.quantity));
  }

  String? _lastOrderError;
  String? get lastOrderError => _lastOrderError;

  Future<Order?> placeOrder({
    String paymentMethod = "COD",
    http.Client? client,
    String? overrideToken,
  }) async {
    _lastOrderError = null;

    if (_orderItems.isEmpty) {
      _lastOrderError = "Your order tray is empty.";
      debugPrint("[Serveo Order] Attempted placeOrder with empty tray.");
      return null;
    }

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint("[Serveo Order] FirebaseAuth not initialized or unavailable: $e");
    }

    if (overrideToken == null && user == null) {
      _lastOrderError = "Please sign in to place your order.";
      debugPrint("[Serveo Order] User is not authenticated in Firebase Auth.");
      return null;
    }

    String? token = overrideToken;
    if (token == null && user != null) {
      try {
        token = await user.getIdToken();
      } catch (e) {
        debugPrint("[Serveo Order] Failed to obtain Firebase ID token: $e");
      }
    }

    if (token == null || token.isEmpty) {
      _lastOrderError = "Session expired. Please sign in again.";
      debugPrint("[Serveo Order] Empty or missing Firebase ID token.");
      return null;
    }

    final httpClient = client ?? http.Client();
    final url = Uri.parse("${ApiConfig.baseUrl}/order/add");
    final cartItemsSnapshot = _orderItems.map((item) => item.toJson()).toList();
    final totalAmountSnapshot = getTotal();

    try {
      final response = await httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "orderItems": cartItemsSnapshot,
          "paymentMethod": paymentMethod,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = jsonDecode(response.body);

        // Case 1: Backend returns modern format with { order: { ... } }
        if (data is Map && data['order'] != null) {
          _lastOrderError = null;
          _orderItems.clear();
          notifyListeners();
          return Order.fromJson(Map<String, dynamic>.from(data['order']));
        }

        // Case 2: Order object returned directly
        if (data is Map && (data['_id'] != null || data['totalAmount'] != null)) {
          _lastOrderError = null;
          _orderItems.clear();
          notifyListeners();
          return Order.fromJson(Map<String, dynamic>.from(data));
        }

        // Case 3: Deployed/legacy backend returns { message: "Order Placed !!" } without 'order' key
        debugPrint("[Serveo Order] Backend accepted order (HTTP ${response.statusCode}), resolving order details...");

        try {
          final userOrdersRes = await httpClient.get(
            Uri.parse("${ApiConfig.baseUrl}/order/user"),
            headers: {"Authorization": "Bearer $token"},
          ).timeout(const Duration(seconds: 8));

          if (userOrdersRes.statusCode == 200) {
            final decoded = jsonDecode(userOrdersRes.body);
            final List<dynamic>? list = decoded is Map ? decoded['message'] : null;
            if (list != null && list.isNotEmpty) {
              _lastOrderError = null;
              _orderItems.clear();
              notifyListeners();
              return Order.fromJson(Map<String, dynamic>.from(list.first));
            }
          }
        } catch (fetchErr) {
          debugPrint("[Serveo Order] Secondary order fetch exception: $fetchErr");
        }

        // Fallback: Construct Order from accepted cart details so customer can proceed smoothly
        final String orderId = (data is Map && (data['_id'] ?? data['id'] ?? data['orderId']) != null)
            ? (data['_id'] ?? data['id'] ?? data['orderId']).toString()
            : "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

        final fallbackOrder = Order(
          id: orderId,
          totalAmount: totalAmountSnapshot,
          status: "Processing",
          orderDate: DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 16),
          orderItems: cartItemsSnapshot,
          paymentMethod: paymentMethod,
          paymentStatus: paymentMethod == "Card" ? "Verified" : "Pending",
        );

        _lastOrderError = null;
        _orderItems.clear();
        notifyListeners();
        return fallbackOrder;
      }

      // Handle non-200/201 responses
      String serverErrorMsg = "";
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          serverErrorMsg = (decoded['error'] ?? decoded['message'] ?? "").toString();
        }
      } catch (_) {}

      if (response.statusCode == 401) {
        _lastOrderError = "Authentication failed. Please sign in again.";
      } else if (response.statusCode == 400) {
        _lastOrderError = serverErrorMsg.isNotEmpty
            ? serverErrorMsg
            : "Invalid order request. Please review your cart.";
      } else if (response.statusCode >= 500) {
        _lastOrderError = "Server is temporarily unavailable. Please try again shortly.";
      } else {
        _lastOrderError = serverErrorMsg.isNotEmpty
            ? serverErrorMsg
            : "Failed to place order (HTTP ${response.statusCode}).";
      }

      debugPrint("[Serveo Order] Request to POST $url failed (${response.statusCode}): $_lastOrderError");
      // Preserves _orderItems so customer never loses their tray!
      return null;
    } on TimeoutException {
      _lastOrderError = "Server took too long to respond. It may be waking up. Please try again.";
      debugPrint("[Serveo Order] Connection timed out after 25s calling POST $url");
      return null;
    } catch (e) {
      _lastOrderError = "Unable to connect to server. Please check your internet connection.";
      debugPrint("[Serveo Order] Network error calling POST $url: $e");
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  Future<bool> claimPayment(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    try {
      final response = await patch(
        Uri.parse("${ApiConfig.baseUrl}/order/claim-payment"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "orderId": orderId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("claimPayment error: $e");
      return false;
    }
  }

  // Add these variables inside OrderProvider
  List<Order> _myOrders = [];
  List<Order> get myOrders => _myOrders;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchMyOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await get(
        Uri.parse("${ApiConfig.baseUrl}/order/user"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['message'];
        _myOrders = data.map((json) => Order.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void showToast(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Poppins', color: Colors.black)),
        backgroundColor: Colors.yellow,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class Order {
  final String id;
  final int totalAmount;
  final String status;
  final String orderDate;
  final List<dynamic> orderItems;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? paymentClaimedAt;
  final DateTime? paymentVerifiedAt;

  Order({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    required this.orderItems,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'Pending',
    this.paymentClaimedAt,
    this.paymentVerifiedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: (json['_id'] ?? json['id'] ?? json['orderId'] ?? '').toString(),
      totalAmount: int.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'Processing',
      orderDate: json['createdAt'] != null && json['createdAt'].toString().length >= 16
          ? json['createdAt'].toString().replaceFirst('T', ' ').substring(0, 16)
          : (json['orderDate'] ?? json['createdAt']?.toString() ?? ''),
      orderItems: json['orderItems'] ?? [],
      paymentMethod: json['paymentMethod'] ?? 'COD',
      paymentStatus: json['paymentStatus'] ?? 'Pending',
      paymentClaimedAt: json['paymentClaimedAt'] != null
          ? DateTime.tryParse(json['paymentClaimedAt'].toString())
          : null,
      paymentVerifiedAt: json['paymentVerifiedAt'] != null
          ? DateTime.tryParse(json['paymentVerifiedAt'].toString())
          : null,
    );
  }
}

class Item{
  final String itemId, itemName, category;
  final int itemPrice;
  final String? description;
  final bool isAvailable;
  final String? imageUrl;
  int quantity = 0;

  Item({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.category,
    this.description,
    this.isAvailable = true,
    this.imageUrl,
  });

  factory Item.fromJson(Map<String,dynamic> json){
    return Item(
      itemId: json['_id'] ?? '',
      itemName: json['itemName'] ?? '',
      itemPrice: json['itemPrice'] != null ? int.parse(json['itemPrice'].toString()) : 0,
      category: json['category'] ?? '',
      description: json['description'],
      isAvailable: json['isAvailable'] ?? true,
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'quantity': quantity,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
    };
  }
}