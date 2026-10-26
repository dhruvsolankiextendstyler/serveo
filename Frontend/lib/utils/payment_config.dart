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
}
