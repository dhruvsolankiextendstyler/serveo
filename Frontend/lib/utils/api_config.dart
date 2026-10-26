import 'package:flutter/foundation.dart';

class ApiConfig {
  // Production deployed backend URL (Render)
  static const String prodUrl = 'https://serveo-foods.onrender.com';

  // Local development backend URL
  // On Android emulator, localhost is 10.0.2.2; on web/desktop, it is localhost
  static String get localUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  // Set to true only if you want to explicitly test against a locally running server on port 5000
  static const bool useLocalBackend = false;

  // Uses Render deployed backend by default so that all devices/emulators connect successfully
  static String get baseUrl {
    if (useLocalBackend) {
      return localUrl;
    }
    return prodUrl;
  }

  /// Resolves an image URL (whether relative or absolute) against the active backend.
  static String resolveImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$baseUrl$cleanPath';
  }
}

