// lib/screens/add_item_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/models/wardrobe_model.dart';
import 'package:wtw/services/wardrobe_photo_helper.dart';
import 'package:wtw/utils/image_compress.dart';
import 'package:wtw/services/ai_stylist_service.dart';
import 'package:wtw/services/ai_cache.dart';
import 'package:wtw/services/firebase_wardrobe_service.dart';
import 'package:image_picker/image_picker.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final WardrobePhotoHelper _photoHelper = WardrobePhotoHelper();
  File? _pickedFile;
  String _category = '';
  bool _saving = false;

  Future<void> _pickFromGallery() async {
    final file = await _photoHelper.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _pickedFile = file);
  }

  Future<void> _pickFromCamera() async {
    final file = await _photoHelper.pickImage(source: ImageSource.camera);
    if (file == null) return;
    setState(() => _pickedFile = file);
  }

  Future<void> _saveItem() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a photo')),
      );
      return;
    }
    if (_category.trim().isEmpty) _category = 'Untitled';

    setState(() => _saving = true);
    try {
      final wardrobe = Provider.of<WardrobeModel>(context, listen: false);

      // Save locally first (fast)
      debugPrint('[AddItem] Saving image locally...');
      final savedFile = await _photoHelper.saveImagePermanently(_pickedFile!);
      final item = WardrobeItem(imagePath: savedFile.path, title: _category);
      await wardrobe.addItem(item);
      
      debugPrint('[AddItem] Local save complete, closing screen...');
      
      // Close screen IMMEDIATELY
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item saved! Processing in background...'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
      
      // Start Firebase upload in background (don't wait)
      debugPrint('[AddItem] Starting Firebase upload in background...');
      _uploadAndProcessInBackground(savedFile, _category);
      
    } catch (e) {
      debugPrint('[AddItem] Save item error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<String?> _uploadToFirebaseInBackground(File file, String category) async {
    try {
      debugPrint('[Firebase] Starting upload...');
      final firebaseService = FirebaseWardrobeService.instance;
      final itemId = await firebaseService.uploadItemWithPhoto(
        photoFile: file,
        category: category,
      );
      debugPrint('[Firebase] Upload successful! Item ID: $itemId');
      return itemId;
    } catch (e) {
      debugPrint('[Firebase] Upload error: $e');
      rethrow;
    }
  }

  // Executes Firebase upload AND AI processing in background (non-blocking)
  void _uploadAndProcessInBackground(File file, String category) {
    Future<void>(() async {
      try {
        // Upload to Firebase
        debugPrint('[BG] Starting Firebase upload...');
        final firebaseService = FirebaseWardrobeService.instance;
        await firebaseService.uploadItemWithPhoto(
          photoFile: file,
          category: category,
        );
        debugPrint('[BG] Firebase upload complete');

        // Refresh wardrobe from Firebase
        debugPrint('[BG] Refreshing wardrobe...');
        final wardrobe = Provider.of<WardrobeModel?>(context, listen: false);
        if (wardrobe != null) {
          await wardrobe.refreshItemsFromFirebase();
          debugPrint('[BG] Wardrobe refreshed');
        }
      } catch (e) {
        debugPrint('[BG] Firebase upload failed: $e');
      }

      try {
        // Process image with AI
        debugPrint('[BG] Starting AI processing...');
        await _processAndCacheImage(file);
        debugPrint('[BG] AI processing complete');
      } catch (e) {
        debugPrint('[BG] AI processing failed: $e');
      }
    }).ignore(); // Fire and forget
  }

  Future<void> _processAndCacheImage(File file) async {
    try {
      debugPrint('[AI] process start for ${file.path}');

      if (!Hive.isBoxOpen('ai_cache')) {
        debugPrint('[AI] ai_cache box is not open — opening now');
        await Hive.openBox('ai_cache');
      }

      await AICache.put(file.path, {'status': 'processing'});
      debugPrint('[AI] status set to processing for ${file.path}');

      File compressed;
      try {
        compressed = await compressImage(file);
        final size = await compressed.length();
        debugPrint('[AI] compressed file size=$size bytes for ${file.path}');
      } catch (e, st) {
        debugPrint('[AI] compress failed: $e\n$st');
        await AICache.put(file.path, {
          'status': 'error',
          'error': 'compress_failed: $e',
        });
        return;
      }

      Map<String, dynamic> desc;
      try {
        final ai = AIStylistService();
        desc = await ai.describeClothes(compressed);
        debugPrint('[AI] describe result for ${file.path}: $desc');
      } catch (e, st) {
        debugPrint('[AI] describeClothes failed: $e\n$st');
        await AICache.put(file.path, {
          'status': 'error',
          'error': e.toString(),
        });
        return;
      }

      await AICache.put(file.path, {
        ...desc,
        'status': 'done',
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[AI] saved description into cache for ${file.path}');
    } catch (e, st) {
      debugPrint('[AI] unexpected error: $e\n$st');
      try {
        await AICache.put(file.path, {
          'status': 'error',
          'error': e.toString(),
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        foregroundColor: const Color(0xFF4B4CFF),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _pickedFile == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            onPressed: _pickFromGallery,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            onPressed: _pickFromCamera,
                          ),
                        ],
                      )
                    : Image.file(_pickedFile!, fit: BoxFit.contain),
              ),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => _category = v,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveItem,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B4CFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
