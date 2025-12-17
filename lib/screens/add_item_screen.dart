// lib/screens/add_item_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/models/wardrobe_model.dart';
import 'package:wtw/services/wardrobe_photo_helper.dart';
import 'package:wtw/utils/image_compress.dart';
import 'package:wtw/services/ai_stylist_service.dart';
import 'package:wtw/services/firebase_wardrobe_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

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
      final item = WardrobeItem(imagePath: savedFile.path, title: _category, id: null);
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

  // Executes Firebase upload AND AI processing in background (non-blocking)
  void _uploadAndProcessInBackground(File file, String category) {
    debugPrint('[BG] ⏳ Starting background upload and AI processing...');
    debugPrint('[BG] File path: ${file.path}');
    
    // Run in background without blocking
    _uploadAndProcessBackgroundAsync(file, category);
  }

  Future<void> _uploadAndProcessBackgroundAsync(File file, String category) async {
    debugPrint('[BG] 🚀 Background async started');
    String? itemId;
    try {
      // Upload to Firebase
      debugPrint('[BG] 📤 Starting Firebase upload...');
      final firebaseService = FirebaseWardrobeService.instance;
      itemId = await firebaseService.uploadItemWithPhoto(
        photoFile: file,
        category: category,
      );
      debugPrint('[BG] ✅ Firebase upload complete, itemId=$itemId, itemId is not null: ${itemId != null}');
      
      // Wait a moment to ensure document is fully written before AI processing
      debugPrint('[BG] ⏱️ Waiting 1000ms before AI processing...');
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('[BG] ⏱️ Wait complete');
    } catch (e, st) {
      debugPrint('[BG] ❌ Firebase upload failed: $e\n$st');
      return; // Stop if upload fails
    }

    try {
      // Process image with AI
      debugPrint('[BG] 🤖 Starting AI processing with itemId=$itemId...');
      await _processAndCacheImage(file, itemId: itemId);
      debugPrint('[BG] ✅ AI processing complete');
      
      // Firebase listener will automatically update the UI when AI data is saved
    } catch (e, st) {
      debugPrint('[BG] ❌ AI processing failed: $e\n$st');
    }
    
    debugPrint('[BG] 🏁 Background async ended');
  }

  Future<void> _processAndCacheImage(File file, {String? itemId}) async {
    try {
      debugPrint('[AI] 📸 process start for ${file.path}, itemId=$itemId');
      
      if (itemId == null || itemId.isEmpty) {
        debugPrint('[AI] ⚠️ WARNING: itemId is null/empty, cannot process');
        return;
      }

      File compressed;
      try {
        debugPrint('[AI] 🗜️ Compressing image...');
        compressed = await compressImage(file);
        final size = await compressed.length();
        debugPrint('[AI] ✅ compressed file size=$size bytes for ${file.path}');
      } catch (e, st) {
        debugPrint('[AI] ❌ compress failed: $e\n$st');
        return;
      }

      Map<String, dynamic> desc;
      try {
        debugPrint('[AI] 🔍 Calling OpenAI describeClothes...');
        final ai = AIStylistService();
        desc = await ai.describeClothes(compressed);
        debugPrint('[AI] ✅ describe result for ${file.path}: $desc');
      } catch (e, st) {
        debugPrint('[AI] ❌ describeClothes failed: $e\n$st');
        return;
      }

      final cacheData = {
        ...desc,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      debugPrint('[AI] ✅ AI processing complete for ${file.path}');
      debugPrint('[AI] 📝 itemId=$itemId, itemId!=null=${itemId != null}, isEmpty=${itemId.isEmpty ?? true}');
      
      // Update Firestore with AI characteristics if itemId is available
      if (itemId.isNotEmpty) {
        try {
          debugPrint('[AI] 💾 Updating Firestore document $itemId with AI data...');
          debugPrint('[AI] 💾 Data to save: $cacheData');
          final firebaseService = FirebaseWardrobeService.instance;
          await firebaseService.updateItemWithAIData(itemId, cacheData);
          debugPrint('[AI] ✅ Firestore document updated successfully');
          debugPrint('[AI] 🔄 Stream listener should update UI automatically');
          // Firebase listener will automatically update the UI
        } catch (e, st) {
          debugPrint('[AI] ❌ Failed to update Firestore: $e\n$st');
          // Don't fail the whole process if Firestore update fails
        }
      } else {
        debugPrint('[AI] ⚠️ WARNING: itemId is null or empty, skipping Firestore update');
      }
    } catch (e, st) {
      debugPrint('[AI] ❌ unexpected error: $e\n$st');
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B4CFF),
                ),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
