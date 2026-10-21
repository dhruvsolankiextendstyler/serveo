class AdminOrder {
  final String id, uid, orderDate;
  final List orderItems;
  final int totalAmount;
  final DateTime? createdAt;
  String status;

  AdminOrder({
    required this.id,
    required this.uid,
    required this.orderItems,
    required this.orderDate,
    required this.totalAmount,
    required this.status,
    this.createdAt,
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

    return AdminOrder(
      id: json['_id'] ?? '',
      uid: json['userId'] ?? '',
      orderItems: json['orderItems'] ?? [],
      orderDate: formattedDate,
      totalAmount: int.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'Processing',
      createdAt: parsedDate,
    );
  }

  /// Formats order placement time in Asia/Kolkata timezone (UTC+5:30)
  /// e.g. "7:42 PM" for today's orders or "21 Oct, 7:42 PM" for older dates.
  String get formattedPlacementTime {
    if (createdAt == null) return orderDate;

    // Convert to Asia/Kolkata (UTC + 5:30)
    final utc = createdAt!.toUtc();
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