import 'package:flutter/foundation.dart';

class ApiConfig {
  // Local development backend URL
  static const String localUrl = 'http://localhost:5000';

  // Production deployed backend URL (update when backend is deployed to Render/Railway/Cloud Run)
  static const String prodUrl = 'https://serveo-foods.onrender.com';

  // Automatically selects local URL in debug mode and prod URL in release builds
  static String get baseUrl {
    if (kDebugMode) {
      return localUrl;
    }
    return prodUrl;
  }
}
