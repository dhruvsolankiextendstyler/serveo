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
    return _orderItems
        .where((it) => it.itemId == itemId)
        .fold(0, (sum, it) => sum + it.quantity);
  }

  void addToCart(Item item, [BuildContext? context]){
    int index = _orderItems.indexWhere((it) => it.cartKey == item.cartKey);
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
    int index = _orderItems.indexWhere((it) => it.cartKey == item.cartKey);
    if (index != -1) {
      if (_orderItems[index].quantity > 1) {
        _orderItems[index].quantity -= 1;
      } else {
        _orderItems.removeAt(index); // Remove item if it hits 0
      }
      notifyListeners();
    }
  }

  void removeItem(Item item) {
    _orderItems.removeWhere((it) => it.cartKey == item.cartKey);
    notifyListeners();
  }

  void clearCart() {
    _orderItems.clear();
    notifyListeners();
  }

  int getTotal(){
    return _orderItems.fold(0, (total, item) => total + (item.effectiveUnitPrice * item.quantity));
  }

  String? _lastOrderError;
  String? get lastOrderError => _lastOrderError;

  Future<Order?> placeOrder({
    String paymentMethod = "COD",
    http.Client? client,
    String? overrideToken,
    String? restaurantId,
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
          if (restaurantId != null && restaurantId.isNotEmpty) "restaurantId": restaurantId,
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
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "orderId": orderId,
        }),
      );
      if (response.statusCode == 200) {
        await trackOrder(orderId);
        await fetchMyOrders();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("claimPayment error: $e");
      return false;
    }
  }

  // Persistent In-App Notifications
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => _notifications;
  int _unreadNotificationCount = 0;
  int get unreadNotificationCount => _unreadNotificationCount;

  Future<void> fetchNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/order/notifications/user"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          _notifications = List<Map<String, dynamic>>.from(decoded['notifications'] ?? []);
          _unreadNotificationCount = int.tryParse(decoded['unreadCount']?.toString() ?? '0') ?? 0;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("fetchNotifications error: $e");
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final response = await http.patch(
        Uri.parse("${ApiConfig.baseUrl}/order/notifications/$id/read"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final idx = _notifications.indexWhere((n) => n['_id']?.toString() == id);
        if (idx != -1 && _notifications[idx]['isRead'] != true) {
          _notifications[idx]['isRead'] = true;
          if (_unreadNotificationCount > 0) _unreadNotificationCount--;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final response = await http.patch(
        Uri.parse("${ApiConfig.baseUrl}/order/notifications/read-all"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
        _unreadNotificationCount = 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  // Customer Feedback
  Future<bool> submitFeedback({
    required String orderId,
    required int rating,
    required String comment,
    List<String> tags = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/order/feedback"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "orderId": orderId,
          "rating": rating,
          "comment": comment,
          "tags": tags,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint("submitFeedback error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> getOrderFeedback(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/order/feedback/order/$orderId"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['feedback'] != null) {
          return Map<String, dynamic>.from(decoded['feedback']);
        }
      }
    } catch (_) {}
    return null;
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

  /// Fetches real-time status of a single order for live tracking.
  Future<Order?> trackOrder(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/order/track/$orderId"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['order'] != null) {
          final liveOrder = Order.fromJson(Map<String, dynamic>.from(decoded['order']));
          // Update in cached list if present
          final idx = _myOrders.indexWhere((o) => o.id == liveOrder.id);
          if (idx != -1) {
            _myOrders[idx] = liveOrder;
            notifyListeners();
          }
          return liveOrder;
        }
      }
    } catch (e) {
      debugPrint("[Serveo Order] trackOrder error: $e");
    }

    // Fallback: check in-memory orders if network fails or endpoint pending
    final localMatch = _myOrders.where((o) => o.id == orderId);
    if (localMatch.isNotEmpty) {
      return localMatch.first;
    }
    return null;
  }

  /// Reorder items from a historical order:
  /// - Matches items against current catalog
  /// - Enforces current prices (never silently charges historical prices)
  /// - Filters out sold-out or deleted items
  /// - Merges into cart without automatic order placement
  ReorderResult reorderOrder(Order order, List<Item> currentCatalog) {
    final List<ReorderItemInfo> addedItems = [];
    final List<String> unavailableOrDeleted = [];
    final List<PriceChangeInfo> priceChanges = [];

    for (final rawItem in order.orderItems) {
      final itemMap = rawItem is Map ? rawItem : {};
      final String rawId = (itemMap['itemId'] ?? itemMap['_id'] ?? '').toString();
      final String rawName = (itemMap['itemName'] ?? itemMap['name'] ?? 'Unknown Item').toString();
      final int histPrice = int.tryParse(itemMap['itemPrice']?.toString() ?? '0') ?? 0;
      final int reqQty = int.tryParse(itemMap['quantity']?.toString() ?? '1') ?? 1;

      // Find in current catalog
      Item? catalogItem;
      if (rawId.isNotEmpty) {
        try {
          catalogItem = currentCatalog.firstWhere((c) => c.itemId == rawId);
        } catch (_) {}
      }
      if (catalogItem == null && rawName.isNotEmpty) {
        try {
          catalogItem = currentCatalog.firstWhere(
            (c) => c.itemName.toLowerCase().trim() == rawName.toLowerCase().trim(),
          );
        } catch (_) {}
      }

      // Check item validity & availability
      if (catalogItem == null) {
        unavailableOrDeleted.add("$rawName (Discontinued)");
        continue;
      }

      if (!catalogItem.isAvailable) {
        unavailableOrDeleted.add("$rawName (Sold Out)");
        continue;
      }

      // Check price changes
      if (catalogItem.itemPrice != histPrice) {
        priceChanges.add(PriceChangeInfo(
          itemName: catalogItem.itemName,
          oldPrice: histPrice,
          newPrice: catalogItem.itemPrice,
        ));
      }

      // Add to cart with current catalog price
      final int existingQty = getItemQuantity(catalogItem.itemId);
      final int toAdd = (existingQty + reqQty).clamp(1, 3) - existingQty;

      if (toAdd > 0) {
        for (int i = 0; i < toAdd; i++) {
          addToCart(catalogItem);
        }
        addedItems.add(ReorderItemInfo(
          itemName: catalogItem.itemName,
          currentPrice: catalogItem.itemPrice,
          quantityAdded: toAdd,
        ));
      }
    }

    notifyListeners();

    return ReorderResult(
      addedItems: addedItems,
      unavailableItems: unavailableOrDeleted,
      priceChanges: priceChanges,
    );
  }

  void showToast(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins', color: Colors.black)),
        backgroundColor: Colors.yellow,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class ReorderItemInfo {
  final String itemName;
  final int currentPrice;
  final int quantityAdded;

  ReorderItemInfo({
    required this.itemName,
    required this.currentPrice,
    required this.quantityAdded,
  });
}

class PriceChangeInfo {
  final String itemName;
  final int oldPrice;
  final int newPrice;

  PriceChangeInfo({
    required this.itemName,
    required this.oldPrice,
    required this.newPrice,
  });
}

class ReorderResult {
  final List<ReorderItemInfo> addedItems;
  final List<String> unavailableItems;
  final List<PriceChangeInfo> priceChanges;

  ReorderResult({
    required this.addedItems,
    required this.unavailableItems,
    required this.priceChanges,
  });

  bool get hasAddedItems => addedItems.isNotEmpty;
  bool get hasUnavailableItems => unavailableItems.isNotEmpty;
  bool get hasPriceChanges => priceChanges.isNotEmpty;
}

class CustomizationOption {
  final String name;
  final int price;

  CustomizationOption({required this.name, this.price = 0});

  factory CustomizationOption.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final p = rawPrice != null ? (int.tryParse(rawPrice.toString()) ?? (double.tryParse(rawPrice.toString())?.round() ?? 0)) : 0;
    return CustomizationOption(
      name: (json['name'] ?? '').toString(),
      price: p,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
  };
}

class CustomizationGroup {
  final String name;
  final String type; // 'single' | 'multiple'
  final bool required;
  final List<CustomizationOption> options;

  CustomizationGroup({
    required this.name,
    this.type = 'single',
    this.required = false,
    required this.options,
  });

  bool get isSingle => type == 'single';

  factory CustomizationGroup.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List? ?? [])
        .map((o) => CustomizationOption.fromJson(Map<String, dynamic>.from(o)))
        .toList();
    return CustomizationGroup(
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'single').toString(),
      required: json['required'] == true || json['required'] == 'true',
      options: opts,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'required': required,
    'options': options.map((o) => o.toJson()).toList(),
  };
}

class SelectedCustomization {
  final String customizationName;
  final String optionName;
  final int price;

  SelectedCustomization({
    required this.customizationName,
    required this.optionName,
    this.price = 0,
  });

  factory SelectedCustomization.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final p = rawPrice != null ? (int.tryParse(rawPrice.toString()) ?? (double.tryParse(rawPrice.toString())?.round() ?? 0)) : 0;
    return SelectedCustomization(
      customizationName: (json['customizationName'] ?? '').toString(),
      optionName: (json['optionName'] ?? '').toString(),
      price: p,
    );
  }

  Map<String, dynamic> toJson() => {
    'customizationName': customizationName,
    'optionName': optionName,
    'price': price,
  };
}

class Order {
  final String id;
  final int totalAmount;
  final String status;
  final String orderDate;
  final List<dynamic> orderItems;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentRejectionReason;
  final List<Map<String, dynamic>> verificationAttempts;
  final int? estimatedPrepTime;
  final DateTime? estimatedReadyAt;
  final DateTime? paymentClaimedAt;
  final DateTime? paymentVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    required this.orderItems,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'Pending',
    this.paymentRejectionReason,
    this.verificationAttempts = const [],
    this.estimatedPrepTime,
    this.estimatedReadyAt,
    this.paymentClaimedAt,
    this.paymentVerifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isTerminal =>
      ['Collected', 'Completed', 'Cancelled'].contains(status);

  bool get isCancelled =>
      ['Cancelled', 'Payment Rejected'].contains(status);

  bool get isPaymentRejected =>
      paymentStatus == 'Rejected' || status == 'Payment Rejected';

  bool get isAwaitingVerification =>
      paymentStatus == 'Awaiting Verification' || status == 'Pending Verification';

  bool get isPaid => paymentStatus == 'Verified';

  int get attemptCount =>
      verificationAttempts.isNotEmpty ? verificationAttempts.length : (isPaymentRejected || isAwaitingVerification ? 1 : 0);

  factory Order.fromJson(Map<String, dynamic> json) {
    final cAt = json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null;
    final uAt = json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null;
    final eAt = json['estimatedReadyAt'] != null ? DateTime.tryParse(json['estimatedReadyAt'].toString()) : null;

    final rawAttempts = json['verificationAttempts'];
    final List<Map<String, dynamic>> parsedAttempts = [];
    if (rawAttempts is List) {
      for (final a in rawAttempts) {
        if (a is Map) {
          parsedAttempts.add(Map<String, dynamic>.from(a));
        }
      }
    }

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
      paymentRejectionReason: json['paymentRejectionReason']?.toString(),
      verificationAttempts: parsedAttempts,
      estimatedPrepTime: int.tryParse(json['estimatedPrepTime']?.toString() ?? ''),
      estimatedReadyAt: eAt,
      paymentClaimedAt: json['paymentClaimedAt'] != null
          ? DateTime.tryParse(json['paymentClaimedAt'].toString())
          : null,
      paymentVerifiedAt: json['paymentVerifiedAt'] != null
          ? DateTime.tryParse(json['paymentVerifiedAt'].toString())
          : null,
      createdAt: cAt,
      updatedAt: uAt,
    );
  }
}

class Item {
  final String itemId, itemName, category;
  final int itemPrice;
  final String? description;
  final bool isAvailable;
  final String? imageUrl;
  final bool isVeg;
  final String dietary;
  final List<CustomizationGroup> customizations;
  final List<SelectedCustomization> selectedCustomizations;
  int quantity = 0;

  Item({
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    required this.category,
    this.description,
    this.isAvailable = true,
    this.imageUrl,
    this.isVeg = true,
    this.dietary = 'Veg',
    this.customizations = const [],
    this.selectedCustomizations = const [],
  });

  bool get hasCustomizations => customizations.isNotEmpty;
  int get customizationsTotal => selectedCustomizations.fold(0, (sum, c) => sum + c.price);
  int get effectiveUnitPrice => itemPrice + customizationsTotal;
  String get cartKey => "$itemId:${selectedCustomizations.map((c) => "${c.customizationName}=${c.optionName}").join(';')}";

  Item copyWith({
    String? itemId,
    String? itemName,
    int? itemPrice,
    String? category,
    String? description,
    bool? isAvailable,
    String? imageUrl,
    bool? isVeg,
    String? dietary,
    int? quantity,
    List<CustomizationGroup>? customizations,
    List<SelectedCustomization>? selectedCustomizations,
  }) {
    final copy = Item(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      category: category ?? this.category,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      isVeg: isVeg ?? this.isVeg,
      dietary: dietary ?? this.dietary,
      customizations: customizations ?? this.customizations,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
    );
    copy.quantity = quantity ?? this.quantity;
    return copy;
  }

  factory Item.fromJson(Map<String, dynamic> json){
    final dietaryStr = json['dietary']?.toString() ?? 'Veg';
    final bool vegVal = json['isVeg'] ?? (dietaryStr.toLowerCase() != 'non-veg');

    final rawPrice = json['itemPrice'];
    int parsedPrice = 0;
    if (rawPrice != null) {
      parsedPrice = int.tryParse(rawPrice.toString()) ??
          (double.tryParse(rawPrice.toString())?.round() ?? 0);
    }

    final rawCust = json['customizations'];
    final List<CustomizationGroup> parsedGroups = [];
    if (rawCust is List) {
      for (final g in rawCust) {
        if (g is Map) {
          parsedGroups.add(CustomizationGroup.fromJson(Map<String, dynamic>.from(g)));
        }
      }
    }

    final rawSel = json['selectedCustomizations'];
    final List<SelectedCustomization> parsedSel = [];
    if (rawSel is List) {
      for (final s in rawSel) {
        if (s is Map) {
          parsedSel.add(SelectedCustomization.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }

    return Item(
      itemId: (json['_id'] ?? json['id'] ?? json['itemId'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      itemPrice: parsedPrice,
      category: (json['category'] ?? '').toString(),
      description: json['description']?.toString(),
      isAvailable: json['isAvailable'] == null ? true : (json['isAvailable'] == true || json['isAvailable'] == 'true'),
      imageUrl: json['imageUrl']?.toString(),
      isVeg: vegVal,
      dietary: dietaryStr,
      customizations: parsedGroups,
      selectedCustomizations: parsedSel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'quantity': quantity,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      'isVeg': isVeg,
      'dietary': dietary,
      if (selectedCustomizations.isNotEmpty)
        'selectedCustomizations': selectedCustomizations.map((s) => s.toJson()).toList(),
      if (customizations.isNotEmpty)
        'customizations': customizations.map((g) => g.toJson()).toList(),
    };
  }
}