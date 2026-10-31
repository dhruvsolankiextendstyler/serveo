import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_config.dart';
import 'order_provider.dart';

class MenuProvider extends ChangeNotifier {
  List<Item> _menuItems = [];
  bool _isLoading = false;
  List<Item> get menuItems => _menuItems;
  bool get isLoading => _isLoading;

  // Phase 6: Active Promotions & Recommendations State
  List<Map<String, dynamic>> _activeCampaigns = [];
  List<Map<String, dynamic>> get activeCampaigns => _activeCampaigns;

  List<Item> _recommendedItems = [];
  List<Item> get recommendedItems => _recommendedItems;

  String _recommendationReason = "Popular items ready to order";
  String get recommendationReason => _recommendationReason;

  Future<void> fetchMenu({String? restaurantId, Client? client}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final httpClient = client ?? http.Client();
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/item${restaurantId != null && restaurantId.isNotEmpty ? '?restaurantId=$restaurantId' : ''}",
      );
      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List<dynamic> itemsData = decodedData['message'] ?? [];
        _menuItems = itemsData.map((json) => Item.fromJson(json)).toList();
      } else {
        debugPrint("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCampaigns({String? restaurantId, Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final targetId = (restaurantId != null && restaurantId.isNotEmpty) ? restaurantId : "default";
      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/$targetId/campaigns/active");
      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['campaigns'];
        if (list is List) {
          _activeCampaigns = list.map((e) => Map<String, dynamic>.from(e)).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Campaigns fetch error: $e");
    }
  }

  Future<void> recordCampaignClick(String campaignId, {String? restaurantId, Client? client}) async {
    try {
      final httpClient = client ?? http.Client();
      final targetId = (restaurantId != null && restaurantId.isNotEmpty) ? restaurantId : "default";
      final url = Uri.parse("${ApiConfig.baseUrl}/restaurant/$targetId/campaigns/$campaignId/click");
      await httpClient.post(url);
    } catch (_) {}
  }

  Future<void> fetchRecommendations({String? restaurantId, Client? client, String? overrideToken}) async {
    try {
      String? token = overrideToken;
      if (token == null) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) token = await user.getIdToken();
        } catch (_) {}
      }

      final httpClient = client ?? http.Client();
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/item/recommendations${restaurantId != null && restaurantId.isNotEmpty ? '?restaurantId=$restaurantId' : ''}",
      );

      final response = await httpClient.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        _recommendationReason = decoded['reason']?.toString() ?? "Popular items ready to order";
        final list = decoded['recommendations'];
        if (list is List) {
          _recommendedItems = list.map((json) => Item.fromJson(json)).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Recommendations fetch error: $e");
    }
  }
}
