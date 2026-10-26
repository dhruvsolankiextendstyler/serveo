import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'api_config.dart';


class OrderProvider extends ChangeNotifier{
  final List<Item> _orderItems = [];

  List<Item> get orderItems => _orderItems;

  int getItemQuantity(String itemId) {
    int index = _orderItems.indexWhere((it) => it.itemId == itemId);
    return index != -1 ? _orderItems[index].quantity : 0;
  }

  void addToCart(Item item, BuildContext context){
    int index = _orderItems.indexWhere((it) => it.itemId == item.itemId);
    if (index != -1) {
      // 2. Check Quantity Limit (Max 3)
      if (_orderItems[index].quantity < 3) {
        _orderItems[index].quantity++;
      } else {
        showToast("Maximum 3 of the same item allowed!", context);
        return;
      }
    } else {
      // 3. Check Total Unique Items Limit (Max 5)
      if (_orderItems.length < 5) {
        _orderItems.add(item..quantity = 1);
      } else {
        showToast("You can only order up to 5 different items!", context);
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

  Future<Order?> placeOrder({String paymentMethod = "COD"}) async {
    final user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();
    try {
      final response = await post(
          Uri.parse("${ApiConfig.baseUrl}/order/add"),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({
            "orderItems": _orderItems.map((item) => item.toJson()).toList(),
            "paymentMethod": paymentMethod,
          })
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _orderItems.clear();
        notifyListeners();
        if (data is Map && data['order'] != null) {
          return Order.fromJson(data['order']);
        }
      }
    } catch (e) {
      debugPrint("placeOrder error: $e");
    }
    _orderItems.clear();
    notifyListeners();
    return null;
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
      id: json['_id'] ?? '',
      totalAmount: int.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'Processing',
      orderDate: json['createdAt'] != null && json['createdAt'].toString().length >= 16
          ? json['createdAt'].toString().replaceFirst('T', ' ').substring(0, 16)
          : (json['createdAt']?.toString() ?? ''),
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
  int quantity = 0;

  Item({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.category,
    this.description,
    this.isAvailable = true,
  });

  factory Item.fromJson(Map<String,dynamic> json){
    return Item(
      itemId: json['_id'] ?? '',
      itemName: json['itemName'] ?? '',
      itemPrice: json['itemPrice'] != null ? int.parse(json['itemPrice'].toString()) : 0,
      category: json['category'] ?? '',
      description: json['description'],
      isAvailable: json['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'quantity': quantity,
    };
  }
}