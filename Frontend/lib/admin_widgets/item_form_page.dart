import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/api_config.dart';
import '../widgets/breakbite_textbox.dart';

class ItemFormPage extends StatefulWidget {
  final Uint8List? initialImageBytes;
  final String? initialImageName;
  final String? initialCategory;
  final Future<http.Response> Function(http.BaseRequest request)? mockSubmitHandler;

  const ItemFormPage({
    super.key,
    this.initialImageBytes,
    this.initialImageName,
    this.initialCategory,
    this.mockSubmitHandler,
  });

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final TextEditingController itemName = TextEditingController();
  final TextEditingController itemPrice = TextEditingController();
  final TextEditingController category = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;
  int? _imageSizeBytes;
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      category.text = widget.initialCategory!;
    }
    if (widget.initialImageBytes != null) {
      _imageBytes = widget.initialImageBytes;
      _imageName = widget.initialImageName ?? 'food_image.jpg';
      _imageSizeBytes = widget.initialImageBytes!.lengthInBytes;
    }
  }

  @override
  void dispose() {
    itemName.dispose();
    itemPrice.dispose();
    category.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _isSupportedImageFormat(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp')) {
      return true;
    }

    // Check magic bytes as fallback
    if (bytes.length >= 2) {
      if (bytes[0] == 0xff && bytes[1] == 0xd8) return true; // JPEG
      if (bytes[0] == 0x42 && bytes[1] == 0x4d) return true; // BMP
    }
    if (bytes.length >= 8) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) {
        return true; // PNG
      }
      final brand = String.fromCharCodes(bytes.sublist(4, 8));
      if (brand == 'ftyp') return true; // HEIC / HEIF
    }
    return false;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 92,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();

      // Check max size (5 MB limit)
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        setState(() {
          _validationError = "Image exceeds 5MB limit. Please select a smaller photo.";
        });
        return;
      }

      // Check supported image format
      if (!_isSupportedImageFormat(pickedFile.name, bytes)) {
        setState(() {
          _validationError = "Unsupported image format. Allowed: JPG, PNG, HEIC, WebP, GIF, BMP.";
        });
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
        _imageSizeBytes = bytes.lengthInBytes;
        _validationError = null;
      });
    } catch (e) {
      setState(() {
        _validationError = "Failed to pick image: $e";
      });
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _imageSizeBytes = null;
      _validationError = null;
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Food Image",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Choose photo source (optional)",
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                key: const Key('pick_from_gallery_tile'),
                leading: const Icon(Icons.photo_library, color: Colors.yellow),
                title: const Text("Photo Gallery", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Select existing photo from device",
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                key: const Key('pick_from_camera_tile'),
                leading: const Icon(Icons.camera_alt, color: Colors.yellow),
                title: const Text("Camera", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Take a fresh photo of the dish",
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final name = itemName.text.trim();
    final price = itemPrice.text.trim();
    final cat = category.text.trim();

    if (name.isEmpty) {
      _showToast("Please enter an item name", isError: true);
      return;
    }
    if (price.isEmpty) {
      _showToast("Please enter an item price", isError: true);
      return;
    }
    if (cat.isEmpty) {
      _showToast("Please select a category", isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      String? token;
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {
        // Safe for test environments where Firebase is not initialized
      }
      http.Response response;

      if (_imageBytes != null) {
        // Multipart request with optional food image
        final request = http.MultipartRequest(
          'POST',
          Uri.parse("${ApiConfig.baseUrl}/item/add"),
        );

        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.fields['itemName'] = name;
        request.fields['itemPrice'] = price;
        request.fields['category'] = cat;

        request.files.add(http.MultipartFile.fromBytes(
          'image',
          _imageBytes!,
          filename: _imageName ?? 'food_image.jpg',
        ));

        if (widget.mockSubmitHandler != null) {
          response = await widget.mockSubmitHandler!(request);
        } else {
          final streamed = await request.send();
          response = await http.Response.fromStream(streamed);
        }
      } else {
        // Standard JSON request without image (image remains completely optional)
        final headers = {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        };
        final body = jsonEncode({
          "itemName": name,
          "itemPrice": price,
          "category": cat,
        });

        if (widget.mockSubmitHandler != null) {
          final request = http.Request('POST', Uri.parse("${ApiConfig.baseUrl}/item/add"))
            ..headers.addAll(headers)
            ..body = body;
          response = await widget.mockSubmitHandler!(request);
        } else {
          response = await http.post(
            Uri.parse("${ApiConfig.baseUrl}/item/add"),
            headers: headers,
            body: body,
          );
        }
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final message = decoded['message']?.toString() ?? "Item Created Succssfully";

        if (message == "Item Exists!") {
          _showToast("An item named '$name' already exists!", isError: true);
        } else {
          _showToast("Item Added Successfully!", isError: false);
          // Clear form fields
          itemName.clear();
          itemPrice.clear();
          category.clear();
          _removeImage();
        }
      } else {
        final decoded = jsonDecode(response.body);
        final errorMsg = decoded['error'] ??
            decoded['message'] ??
            "Failed to add item (${response.statusCode})";
        _showToast(errorMsg.toString(), isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showToast("Failed to add item: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: screenWidth > 600 ? 400 : screenWidth * 0.9,
            child: Column(
              children: [
                // --- TOP BUN ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD99058), // Toasted Bun Color
                    borderRadius: BorderRadius.vertical(top: Radius.circular(80)),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                    ],
                  ),
                  child: Text(
                    "Add Item",
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  height: 20,
                  color: Colors.yellow,
                ),

                // --- THE "FILLINGS" (TextFields + Optional Food Image) ---
                Container(
                  color: Colors.brown,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ServeoTextBox(
                        hint: "Item Name",
                        icon: Icons.food_bank,
                        cont: itemName,
                      ),
                      const SizedBox(height: 10),
                      ServeoTextBox(
                        hint: "Item Price",
                        icon: Icons.money,
                        cont: itemPrice,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: category.text.isNotEmpty ? category.text : null,
                        hint: Text(
                          "Select Category",
                          style: TextTheme.of(context)
                              .bodyMedium
                              ?.copyWith(color: Colors.brown),
                        ),
                        dropdownColor: Colors.grey[300],
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.brown),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category, color: Colors.brown),
                          filled: true,
                          fillColor: Colors.white70,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextTheme.of(context)
                            .bodyMedium
                            ?.copyWith(color: Colors.brown),
                        items: [
                          "Burgers",
                          "Pizza",
                          "Sandwiches",
                          "Snacks",
                          "Beverages",
                          "Desserts",
                          "Thali",
                          "South Indian"
                        ]
                            .map((label) => DropdownMenuItem(
                                  value: label,
                                  child: Text(label),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            category.text = value;
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // --- 🔹 OPTIONAL FOOD IMAGE FIELD ---
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Header with Optional Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: Colors.yellow, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      "Food Image",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24, width: 0.5),
                                  ),
                                  child: const Text(
                                    "OPTIONAL",
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "JPEG, PNG, HEIC, WebP, GIF, BMP (Max 5MB)",
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 10),

                            // Inline Validation Alert
                            if (_validationError != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.redAccent.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _validationError!,
                                        style: const TextStyle(
                                            color: Colors.redAccent, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // State A: No image selected
                            if (_imageBytes == null)
                              InkWell(
                                key: const Key('select_food_image_card'),
                                onTap: _showImageSourceDialog,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.yellow.withValues(alpha: 0.35),
                                      style: BorderStyle.solid,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded,
                                          color: Colors.yellow, size: 36),
                                      SizedBox(height: 8),
                                      Text(
                                        "Select Food Photo",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "Tap to choose from Gallery or Camera",
                                        style: TextStyle(
                                            color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            // State B: Image selected -> Preview with Replace / Remove
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Stack(
                                      children: [
                                        Image.memory(
                                          _imageBytes!,
                                          key: const Key('food_image_preview'),
                                          height: 135,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            height: 135,
                                            width: double.infinity,
                                            color: Colors.black38,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                    Icons.photo_library_outlined,
                                                    color: Colors.yellow,
                                                    size: 34),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _imageName ?? "HEIC Food Image",
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12),
                                                ),
                                                const SizedBox(height: 2),
                                                const Text(
                                                  "HEIC format converted to JPEG on upload",
                                                  style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _formatFileSize(_imageSizeBytes ?? 0),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _imageName ?? "Selected image",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          key: const Key('replace_food_image_button'),
                                          onPressed: _showImageSourceDialog,
                                          icon: const Icon(Icons.refresh,
                                              size: 14, color: Colors.yellow),
                                          label: const Text("Replace",
                                              style: TextStyle(
                                                  color: Colors.yellow, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.yellow),
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          key: const Key('remove_food_image_button'),
                                          onPressed: _removeImage,
                                          icon: const Icon(Icons.delete_outline,
                                              size: 14, color: Colors.redAccent),
                                          label: const Text("Remove",
                                              style: TextStyle(
                                                  color: Colors.redAccent, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.redAccent),
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- BOTTOM BUN (Submit Button) ---
                Material(
                  color: const Color(0xFFA66D42),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(30)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('add_item_submit_button'),
                    onTap: _isSubmitting ? null : _handleSubmit,
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "Adding Item...",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              "Add Item",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}