class AdminOrder {
  final String id, uid, orderDate;
  final List orderItems;
  final int totalAmount;
  final DateTime? createdAt;
  String status;

  final String customerName;
  final String customerPhone;
  final String customerEmail;

  final String paymentMethod;
  String paymentStatus;
  final DateTime? paymentClaimedAt;
  DateTime? paymentVerifiedAt;
  String? verifiedBy;

  AdminOrder({
    required this.id,
    required this.uid,
    required this.orderItems,
    required this.orderDate,
    required this.totalAmount,
    required this.status,
    this.createdAt,
    this.customerName = 'Customer',
    this.customerPhone = 'N/A',
    this.customerEmail = 'N/A',
    this.paymentMethod = 'COD',
    this.paymentStatus = 'Pending',
    this.paymentClaimedAt,
    this.paymentVerifiedAt,
    this.verifiedBy,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['createdAt'] != null) {
      try {
        parsedDate = DateTime.tryParse(json['createdAt'].toString());
      } catch (_) {}
    }

    String formattedDate = '';
    if (json['createdAt'] != null) {
      final str = json['createdAt'].toString();
      formattedDate = str.length >= 16 ? str.replaceFirst('T', ' ').substring(0, 16) : str;
    }

    // Safely extract customer details from either embedded customerDetails or populated userId
    final userMap = json['userId'] is Map ? json['userId'] as Map<String, dynamic> : null;
    final customerMap = json['customerDetails'] is Map ? json['customerDetails'] as Map<String, dynamic> : null;

    final String cName = customerMap?['fullName'] ?? userMap?['fullName'] ?? 'Customer';
    final String cPhone = customerMap?['phoneNumber'] ?? userMap?['phoneNumber'] ?? 'N/A';
    final String cEmail = customerMap?['email'] ?? userMap?['email'] ?? 'N/A';

    final String userIdString = userMap != null ? (userMap['_id']?.toString() ?? '') : (json['userId']?.toString() ?? '');

    final pClaimed = json['paymentClaimedAt'] != null
        ? DateTime.tryParse(json['paymentClaimedAt'].toString())
        : null;

    final pVerified = json['paymentVerifiedAt'] != null
        ? DateTime.tryParse(json['paymentVerifiedAt'].toString())
        : null;

    return AdminOrder(
      id: json['_id'] ?? '',
      uid: userIdString,
      orderItems: json['orderItems'] ?? [],
      orderDate: formattedDate,
      totalAmount: int.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'Processing',
      createdAt: parsedDate,
      customerName: cName,
      customerPhone: cPhone,
      customerEmail: cEmail,
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
      paymentClaimedAt: pClaimed,
      paymentVerifiedAt: pVerified,
      verifiedBy: json['verifiedBy']?.toString(),
    );
  }

  bool get isUpi => paymentMethod.toUpperCase() == 'UPI';
  bool get isCod => paymentMethod.toUpperCase() == 'COD';
  bool get isAwaitingVerification => paymentStatus == 'Awaiting Verification';
  bool get isVerified => paymentStatus == 'Verified';
  bool get isRejected => paymentStatus == 'Rejected';

  /// Formats order placement time in Asia/Kolkata timezone (UTC+5:30)
  /// e.g. "7:42 PM" for today's orders or "21 Oct, 7:42 PM" for older dates.
  String get formattedPlacementTime => _formatTimeKolkata(createdAt, fallback: orderDate);

  /// Formats full order placement date and time in Asia/Kolkata (e.g. "27 Oct 2026, 12:30 AM")
  String get formattedDateTimeKolkata {
    if (createdAt == null) {
      return orderDate.isNotEmpty ? orderDate : 'N/A';
    }
    final utc = createdAt!.toUtc();
    final kolkataTime = utc.add(const Duration(hours: 5, minutes: 30));

    int hour = kolkataTime.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = kolkataTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $period';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[kolkataTime.month - 1];
    return '${kolkataTime.day} $monthName ${kolkataTime.year}, $timeStr';
  }

  /// Parses orderItems into structured list of maps with itemName, quantity, and itemPrice
  List<Map<String, dynamic>> get parsedOrderItems {
    final List<Map<String, dynamic>> list = [];
    for (final item in orderItems) {
      if (item is Map) {
        final name = (item['itemName'] ?? item['name'] ?? 'Item').toString();
        final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        final price = int.tryParse(item['itemPrice']?.toString() ?? '0') ?? 0;
        list.add({
          'itemName': name,
          'quantity': qty,
          'itemPrice': price,
        });
      } else if (item is String && item.isNotEmpty) {
        list.add({
          'itemName': item,
          'quantity': 1,
          'itemPrice': 0,
        });
      }
    }
    return list;
  }

  /// Formats payment claim time in Asia/Kolkata timezone
  String get formattedClaimTime => _formatTimeKolkata(paymentClaimedAt, fallback: 'N/A');

  /// Formats payment verification time in Asia/Kolkata timezone
  String get formattedVerifiedTime => _formatTimeKolkata(paymentVerifiedAt, fallback: 'N/A');

  static String _formatTimeKolkata(DateTime? dt, {required String fallback}) {
    if (dt == null) return fallback;

    // Convert to Asia/Kolkata (UTC + 5:30)
    final utc = dt.toUtc();
    final kolkataTime = utc.add(const Duration(hours: 5, minutes: 30));
    final nowKolkata = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    int hour = kolkataTime.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final minute = kolkataTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $period';

    final isToday = kolkataTime.year == nowKolkata.year &&
        kolkataTime.month == nowKolkata.month &&
        kolkataTime.day == nowKolkata.day;

    if (isToday) {
      return timeStr;
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[kolkataTime.month - 1];
    return '${kolkataTime.day} $monthName, $timeStr';
  }
}