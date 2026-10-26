/// Configuration for UPI Payment & Store QR Code
/// Easy to configure or update for client demonstrations.
class PaymentConfig {
  /// Merchant / Personal UPI ID for demonstrations (e.g. 'store@okaxis' or GPay ID).
  /// Leave empty or null if no UPI ID is configured yet.
  static const String upiId = "";

  /// Recipient / Merchant business name to display to customers.
  static const String recipientName = "";

  /// Asset path to the UPI QR code image (placed in assets/images/).
  static const String qrAssetPath = "assets/images/upi_qr.png";

  /// Optional remote URL if the QR code is hosted online.
  static const String? qrNetworkUrl = null;

  /// Returns true if either a custom UPI ID or remote/asset QR code has been configured.
  static bool get isConfigured {
    return upiId.trim().isNotEmpty || qrNetworkUrl != null;
  }

  /// Builds a standard UPI Payment Intent URI (e.g. upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...)
  static String? getPaymentIntentUri({required String orderId, required int amount}) {
    if (upiId.trim().isEmpty) return null;
    final name = recipientName.trim().isNotEmpty ? recipientName.trim() : "Serveo Foods";
    return "upi://pay?pa=${upiId.trim()}&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR&tn=Order_$orderId";
  }

  /// Returns the effective QR code image URL:
  /// 1. Direct custom network QR if specified
  /// 2. Dynamically generated UPI intent QR using merchant UPI ID
  /// 3. null if neither is available (falls back to asset QR or setup guidance)
  static String? getQrUrlForOrder({required String orderId, required int amount}) {
    if (qrNetworkUrl != null && qrNetworkUrl!.trim().isNotEmpty) {
      return qrNetworkUrl;
    }
    final intent = getPaymentIntentUri(orderId: orderId, amount: amount);
    if (intent != null) {
      return "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(intent)}";
    }
    return null;
  }
}
