import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/wardrobe_item.dart';
import '../models/outfit.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_wardrobe_service.dart';

class WardrobeModel extends ChangeNotifier {
  final Box<WardrobeItem> _box = Hive.box<WardrobeItem>('wardrobeBox');
  final List<Outfit> _saved = [];
  static late WardrobeModel instance;


  WardrobeModel() {
    instance = this;
    _loadSavedOutfits();
  }

  String _selectedStyle = 'Casual';
  String get selectedStyle => _selectedStyle;

  List<WardrobeItem> get items => _box.values.toList();
  List<Outfit> get saved => List.unmodifiable(_saved);
  static const String _savedBoxName = 'savedOutfits';
  void selectStyle(String style) {
    if (_selectedStyle == style) return;
    _selectedStyle = style;
    notifyListeners();
  }

  List<WardrobeItem> getItemsByKeys(List<String> keys) {
    final found = <WardrobeItem>[];

    for (var k in keys) {
      try {
        final byKey = items.firstWhere((it) {
          final keyStr = it.key?.toString() ?? '';
          return keyStr == k;
        });
        found.add(byKey);
        continue;
      } catch (e) {
      }

      try {
        final byPath = items.firstWhere((it) => it.imagePath == k);
        found.add(byPath);
        continue;
      } catch (e) {
      }
    }

    return found;
  }

  Future<void> addItem(WardrobeItem item) async {
    await _box.add(item);
    notifyListeners();
  }

  Future<void> removeItem(WardrobeItem item) async {
    try {
      debugPrint('[Wardrobe] Removing item: ${item.title}');
      
      // If it's a Firebase item (URL), delete from Firebase
      if (item.isNetworkImage && item.imagePath.contains('firebaseapp')) {
        try {
          debugPrint('[Wardrobe] Item is from Firebase, attempting to delete...');
          final firebaseService = FirebaseWardrobeService.instance;
          
          // Extract item ID from imagePath (contains the itemId)
          // Format: https://firebaseapp.com/.../items/{itemId}/photo.jpg
          final parts = item.imagePath.split('/items/');
          if (parts.length == 2) {
            final itemId = parts[1].split('/')[0];
            debugPrint('[Wardrobe] Deleting Firebase item ID: $itemId');
            await firebaseService.deleteItem(itemId);
            debugPrint('[Wardrobe] Firebase item deleted successfully');
          }
        } catch (e) {
          debugPrint('[Wardrobe] Error deleting from Firebase: $e');
        }
      }
      
      // Delete from local storage
      await item.delete();
      notifyListeners();
      debugPrint('[Wardrobe] Item removed successfully');
    } catch (e) {
      debugPrint('[Wardrobe] Error removing item: $e');
      rethrow;
    }
  }

  Future<void> saveOutfit({
    required String title,
    required List<String> itemKeys,
    required String notes,
  }) async {
    final id = const Uuid().v4();
    final createdAt = DateTime.now().toIso8601String();
    final outfit = Outfit(
      id: id,
      title: title,
      itemKeys: itemKeys,
      notes: notes,
      createdAtIso: createdAt,
    );

    if (!Hive.isBoxOpen(_savedBoxName)) await Hive.openBox(_savedBoxName);
    final box = Hive.box(_savedBoxName);
    await box.put(id, outfit.toMap());

    _saved.insert(0, outfit); // newest first
    notifyListeners();
  }

  Future<void> clearAll() async {
    items.clear();
    saved.clear();
    notifyListeners();
  }

  Future<void> _loadSavedOutfits() async {
    if (!Hive.isBoxOpen(_savedBoxName)) await Hive.openBox(_savedBoxName);
    final box = Hive.box(_savedBoxName);
    _saved.clear();
    for (var key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        _saved.add(Outfit.fromMap(Map<String, dynamic>.from(raw)));
      }
    }
    notifyListeners();
  }

  Future<void> removeSavedById(String id) async {
    if (!Hive.isBoxOpen(_savedBoxName)) await Hive.openBox(_savedBoxName);
    final box = Hive.box(_savedBoxName);
    await box.delete(id);
    _saved.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  // Load items from Firebase
  Future<void> loadItemsFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('[Wardrobe] Loading items from Firebase for user: ${user.uid}');
      
      // Clear local items first to avoid duplicates
      _box.clear();
      
      final firebaseService = FirebaseWardrobeService.instance;
      final firebaseItems = await firebaseService.fetchUserItems();

      debugPrint('[Wardrobe] Fetched ${firebaseItems.length} items from Firebase');

      // Convert Firebase items to WardrobeItems and save to local cache
      for (final itemData in firebaseItems) {
        final photoUrl = itemData['photoUrl'] as String?;
        final title = itemData['title'] as String? ?? 'Untitled';
        
        if (photoUrl != null && photoUrl.isNotEmpty) {
          // Create item with Firebase URL
          final item = WardrobeItem(
            imagePath: photoUrl,
            title: title,
          );
          await _box.add(item);
          debugPrint('[Wardrobe] Added item: $title from Firebase');
        }
      }
      
      debugPrint('[Wardrobe] Loaded ${_box.values.length} items into local cache');
      notifyListeners();
    } catch (e) {
      debugPrint('[Wardrobe] Error loading items from Firebase: $e');
    }
  }

  // Refresh items from Firebase (use after adding new item)
  Future<void> refreshItemsFromFirebase() async {
    debugPrint('[Wardrobe] Refreshing items from Firebase...');
    await loadItemsFromFirebase();
  }
}
