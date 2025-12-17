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

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final WardrobePhotoHelper _helper = WardrobePhotoHelper();
  File? _img;
  String _name = '';
  bool _isSaving = false;

  Future<void> _galleryPick() async {
    final f = await _helper.pickImage(source: ImageSource.gallery);
    if (f == null) return;
    setState(() => _img = f);
  }

  Future<void> _cameraPick() async {
    final f = await _helper.pickImage(source: ImageSource.camera);
    if (f == null) return;
    setState(() => _img = f);
  }

  Future<void> _save() async {
    if (_img == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select image')),
      );
      return;
    }
    
    if (_name.trim().isEmpty) _name = 'Item';

    setState(() => _isSaving = true);
    try {
      final wmodel = Provider.of<WardrobeModel>(context, listen: false);

      final savedF = await _helper.saveImagePermanently(_img!);
      final newItem = WardrobeItem(
        imagePath: savedF.path,
        title: _name,
        id: null,
      );
      await wmodel.addItem(newItem);
      
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved! Processing...'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
      
      _bgUploadAndProcess(savedF, _name);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _bgUploadAndProcess(File f, String cat) {
    _bgAsync(f, cat);
  }

  Future<void> _bgAsync(File f, String cat) async {
    String? itemId;
    try {
      final fb = FirebaseWardrobeService.instance;
      itemId = await fb.uploadItemWithPhoto(
        photoFile: f,
        category: cat,
      );
      
      await Future.delayed(const Duration(milliseconds: 1000));
    } catch (e) {
      return;
    }

    try {
      await _aiProcess(f, itemId: itemId);
    } catch (e) {
      return;
    }
  }

  Future<void> _aiProcess(File f, {String? itemId}) async {
    try {
      if (itemId == null || itemId.isEmpty) {
        return;
      }

      File comp;
      try {
        comp = await compressImage(f);
      } catch (e) {
        return;
      }

      Map<String, dynamic> desc;
      try {
        final aiSvc = AIStylistService();
        desc = await aiSvc.describeClothes(comp);
      } catch (e) {
        return;
      }

      final saveData = {
        ...desc,
        'processed_at': DateTime.now().toIso8601String(),
      };
      
      if (itemId.isNotEmpty) {
        try {
          final fb = FirebaseWardrobeService.instance;
          await fb.updateItemWithAIData(itemId, saveData);
        } catch (e) {
          return;
        }
      }
    } catch (e) {
      return;
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
                child: _img == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            onPressed: _galleryPick,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            onPressed: _cameraPick,
                          ),
                        ],
                      )
                    : Image.file(_img!, fit: BoxFit.contain),
              ),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => _name = v,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B4CFF),
                ),
                child: _isSaving
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
