import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/admin_widgets/item_form_page.dart';
import 'package:frontend/utils/api_config.dart';
import 'package:frontend/utils/order_provider.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:frontend/widgets/breakbite_food_card.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  group('Item Model & ImageUrl Serialization Tests', () {
    test('Item.fromJson correctly parses imageUrl when present', () {
      final json = {
        '_id': 'item_123',
        'itemName': 'Crispy Veg Burger',
        'itemPrice': 120,
        'category': 'Burgers',
        'description': 'Crispy patty with fresh lettuce',
        'isAvailable': true,
        'imageUrl': '/item/image/67abc1234567890abcdef123',
      };

      final item = Item.fromJson(json);
      expect(item.itemId, 'item_123');
      expect(item.itemName, 'Crispy Veg Burger');
      expect(item.itemPrice, 120);
      expect(item.imageUrl, '/item/image/67abc1234567890abcdef123');
    });

    test('Item.fromJson gracefully handles null or missing imageUrl for backwards compatibility', () {
      final json = {
        '_id': 'item_456',
        'itemName': 'Margherita Pizza',
        'itemPrice': 199,
        'category': 'Pizza',
      };

      final item = Item.fromJson(json);
      expect(item.itemId, 'item_456');
      expect(item.imageUrl, isNull);
    });

    test('Item.toJson includes imageUrl when non-empty', () {
      final item = Item(
        itemId: 'item_789',
        itemName: 'Cold Coffee',
        itemPrice: 80,
        category: 'Beverages',
        imageUrl: '/item/image/xyz',
      );

      final json = item.toJson();
      expect(json['itemId'], 'item_789');
      expect(json['imageUrl'], '/item/image/xyz');
    });
  });

  group('ApiConfig.resolveImageUrl Tests', () {
    test('Resolves relative image path with baseUrl', () {
      final resolved = ApiConfig.resolveImageUrl('/item/image/67abc123');
      expect(resolved, contains('/item/image/67abc123'));
      expect(resolved.startsWith('http'), isTrue);
    });

    test('Returns absolute http/https URLs as-is', () {
      const fullUrl = 'https://res.cloudinary.com/serveo/food.png';
      final resolved = ApiConfig.resolveImageUrl(fullUrl);
      expect(resolved, equals(fullUrl));
    });

    test('Returns empty string when imageUrl is null or empty', () {
      expect(ApiConfig.resolveImageUrl(null), equals(''));
      expect(ApiConfig.resolveImageUrl('   '), equals(''));
    });
  });

  group('ItemFormPage Optional Image Upload Widget Tests', () {
    // 1x1 transparent PNG sample bytes
    final samplePngBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    testWidgets('Renders Add Item page with optional image field and OPTIONAL badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemFormPage(),
          ),
        ),
      );

      // Verify header and fields
      expect(find.text('Add Item'), findsWidgets);
      expect(find.text('Food Image'), findsOneWidget);
      expect(find.text('OPTIONAL'), findsOneWidget);
      expect(find.text('Select Food Photo'), findsOneWidget);
      expect(find.text('Tap to choose from Gallery or Camera'), findsOneWidget);
      expect(find.byKey(const Key('select_food_image_card')), findsOneWidget);
    });

    testWidgets('Allows submitting item without an image (Image is purely optional)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      http.BaseRequest? capturedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormPage(
              initialCategory: 'Snacks',
              mockSubmitHandler: (request) async {
                capturedRequest = request;
                return http.Response(jsonEncode({'message': 'Item Created Succssfully'}), 200);
              },
            ),
          ),
        ),
      );

      // Fill in text fields
      await tester.enterText(find.widgetWithText(TextField, 'Item Name'), 'Paneer Roll');
      await tester.enterText(find.widgetWithText(TextField, 'Item Price'), '150');

      // Submit without selecting an image
      final submitButton = find.byKey(const Key('add_item_submit_button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify request was sent as standard JSON request without requiring an image
      expect(capturedRequest, isNotNull);
      expect(capturedRequest is http.Request, isTrue);
      final jsonBody = jsonDecode((capturedRequest as http.Request).body);
      expect(jsonBody['itemName'], 'Paneer Roll');
      expect(jsonBody['itemPrice'], '150');
      expect(jsonBody['category'], 'Snacks');
      expect(find.text('Item Added Successfully!'), findsOneWidget);
    });

    testWidgets('Displays preview, Replace and Remove buttons when image is selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormPage(
              initialImageBytes: samplePngBytes,
              initialImageName: 'delicious_burger.png',
            ),
          ),
        ),
      );

      // Verify image preview is shown
      expect(find.byKey(const Key('food_image_preview')), findsOneWidget);
      expect(find.text('delicious_burger.png'), findsOneWidget);
      expect(find.byKey(const Key('replace_food_image_button')), findsOneWidget);
      expect(find.byKey(const Key('remove_food_image_button')), findsOneWidget);

      // The empty selection card should be hidden
      expect(find.byKey(const Key('select_food_image_card')), findsNothing);
    });

    testWidgets('Removing selected image restores the no-image optional placeholder', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormPage(
              initialImageBytes: samplePngBytes,
              initialImageName: 'sample.png',
            ),
          ),
        ),
      );

      // Verify preview is initially visible
      expect(find.byKey(const Key('food_image_preview')), findsOneWidget);

      // Tap Remove button
      final removeBtn = find.byKey(const Key('remove_food_image_button'));
      await tester.ensureVisible(removeBtn);
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      // Preview should be removed, placeholder restored
      expect(find.byKey(const Key('food_image_preview')), findsNothing);
      expect(find.byKey(const Key('select_food_image_card')), findsOneWidget);
      expect(find.text('Select Food Photo'), findsOneWidget);
    });

    testWidgets('Submitting with an image sends multipart request with attached image file', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      http.BaseRequest? capturedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormPage(
              initialImageBytes: samplePngBytes,
              initialImageName: 'paneer_tikka.png',
              initialCategory: 'Snacks',
              mockSubmitHandler: (request) async {
                capturedRequest = request;
                return http.Response(jsonEncode({'message': 'Item Created Succssfully'}), 200);
              },
            ),
          ),
        ),
      );

      // Fill form fields
      await tester.enterText(find.widgetWithText(TextField, 'Item Name'), 'Paneer Tikka');
      await tester.enterText(find.widgetWithText(TextField, 'Item Price'), '220');

      // Submit form with image
      final submitButton = find.byKey(const Key('add_item_submit_button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify request is multipart with the image file
      expect(capturedRequest, isNotNull);
      expect(capturedRequest is http.MultipartRequest, isTrue);
      final multipart = capturedRequest as http.MultipartRequest;
      expect(multipart.fields['itemName'], 'Paneer Tikka');
      expect(multipart.fields['itemPrice'], '220');
      expect(multipart.fields['category'], 'Snacks');
      expect(multipart.files.length, 1);
      expect(multipart.files.first.field, 'image');
      expect(multipart.files.first.filename, 'paneer_tikka.png');
    });

    testWidgets('Shows validation toast when required fields are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemFormPage(),
          ),
        ),
      );

      // Tap submit with empty form
      await tester.ensureVisible(find.byKey(const Key('add_item_submit_button')));
      await tester.tap(find.byKey(const Key('add_item_submit_button')));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('Please enter an item name'), findsOneWidget);
    });

    testWidgets('Bug 2 — Rejects non-JSON HTML error response without throwing FormatException and preserves form data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemFormPage(
              initialCategory: 'Snacks',
              mockSubmitHandler: (request) async {
                // Simulating Render 502 Bad Gateway / Express HTML error page
                return http.Response(
                  '<!DOCTYPE html>\n<html><head><title>502 Bad Gateway</title></head><body><h1>Bad Gateway</h1></body></html>',
                  502,
                  headers: {'content-type': 'text/html; charset=utf-8'},
                );
              },
            ),
          ),
        ),
      );

      // Fill form fields
      await tester.enterText(find.widgetWithText(TextField, 'Item Name'), 'Gourmet Pasta');
      await tester.enterText(find.widgetWithText(TextField, 'Item Price'), '250');

      // Submit form
      final submitButton = find.byKey(const Key('add_item_submit_button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Form should NOT throw FormatException
      // Friendly error message should be displayed
      expect(find.textContaining('Server returned an unexpected response (502)'), findsOneWidget);

      // Input fields must be preserved, NOT cleared
      expect(find.text('Gourmet Pasta'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
    });

    testWidgets('Validates item price is greater than 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemFormPage(
              initialCategory: 'Snacks',
            ),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Item Name'), 'Free Fries');
      await tester.enterText(find.widgetWithText(TextField, 'Item Price'), '0');

      final submitButton = find.byKey(const Key('add_item_submit_button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid positive price in ₹'), findsOneWidget);
    });
  });

  group('ServeoFoodCard Display Tests', () {
    testWidgets('Renders network image when item has imageUrl', (tester) async {
      final itemWithImage = Item(
        itemId: 'item_img_1',
        itemName: 'Gourmet Burger',
        itemPrice: 180,
        category: 'Burgers',
        description: 'Juicy burger with melted cheese',
        imageUrl: '/item/image/67abc1234567890abcdef123',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => OrderProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ServeoFoodCard(
                item: itemWithImage,
                imagePath: '',
              ),
            ),
          ),
        ),
      );

      // Image.network widget should be in the tree
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Gourmet Burger'), findsOneWidget);
      expect(find.text('₹180'), findsOneWidget);
    });

    testWidgets('Renders fallback category banner when item has no image', (tester) async {
      final itemWithoutImage = Item(
        itemId: 'item_no_img_1',
        itemName: 'Plain Dosa',
        itemPrice: 70,
        category: 'South Indian',
        description: 'Crispy rice crepe',
        imageUrl: '',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => OrderProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ServeoFoodCard(
                item: itemWithoutImage,
                imagePath: '',
              ),
            ),
          ),
        ),
      );

      // Fallback category banner displays category name
      expect(find.text('SOUTH INDIAN'), findsOneWidget);
      expect(find.text('Plain Dosa'), findsOneWidget);
      expect(find.text('₹70'), findsOneWidget);
    });
  });
}
