import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wardrobe_item.dart';
import '../models/outfit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_wardrobe_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class WardrobeModel extends ChangeNotifier {
  final List<WardrobeItem> _items = [];
  final List<Outfit> _saved = [];
  static late WardrobeModel instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseWardrobeService _firebaseService = FirebaseWardrobeService.instance;
  
  StreamSubscription? _itemsSubscription;
  StreamSubscription? _outfitsSubscription;
  String? _currentUserId;

  WardrobeModel() {
    instance = this;
    _setupAuthListener();
  }

  String _selectedStyle = 'Casual';
  String get selectedStyle => _selectedStyle;

  List<WardrobeItem> get items => List.unmodifiable(_items);
  List<Outfit> get saved => List.unmodifiable(_saved);
  
  // Listen to auth state changes
  void _setupAuthListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null && user.uid != _currentUserId) {
        debugPrint('[Wardrobe] 🔄 User switched to: ${user.uid}');
        _currentUserId = user.uid;
        _resetAndInitialize();
      } else if (user == null) {
        debugPrint('[Wardrobe] 🚪 User logged out');
        _currentUserId = null;
        _clearAllData();
      }
    });
  }
  
  // Reset and reinitialize listeners for new user
  void _resetAndInitialize() {
    _clearAllData();
    _initializeFirebaseListener();
    _initializeOutfitsListener();
  }
  
  // Clear all data without notifying
  void _clearAllData() {
    _itemsSubscription?.cancel();
    _outfitsSubscription?.cancel();
    _items.clear();
    _saved.clear();
    debugPrint('[Wardrobe] 🗑️ All data cleared');
    notifyListeners(); // Notify UI to update
  }
  
  // Initialize real-time listener from Firestore
  void _initializeFirebaseListener() {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint('[Wardrobe] Initializing Firebase listener for user: ${user.uid}');
      _itemsSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .snapshots()
          .listen((snapshot) {
        debugPrint('[Wardrobe] 📡 Snapshot received: ${snapshot.docs.length} docs');
        _loadItemsFromSnapshot(snapshot);
      }, onError: (e) {
        debugPrint('[Wardrobe] ❌ Firebase listener error: $e');
      });
    }
  }
  
  // Initialize real-time listener for outfits
  void _initializeOutfitsListener() {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint('[Wardrobe] Initializing outfits listener for user: ${user.uid}');
      _outfitsSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('outfits')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _loadOutfitsFromSnapshot(snapshot);
      }, onError: (e) {
        debugPrint('[Wardrobe] Outfits listener error: $e');
      });
    }
  }
  
  // Load outfits from Firestore snapshot
  void _loadOutfitsFromSnapshot(QuerySnapshot snapshot) {
    _saved.clear();
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final outfit = Outfit(
        id: doc.id,
        title: data['title'] ?? 'Outfit',
        itemKeys: List<String>.from(data['itemKeys'] ?? []),
        notes: data['notes'] ?? '',
        createdAtIso: data['createdAt']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
      );
      _saved.add(outfit);
    }
    
    debugPrint('[Wardrobe] Loaded ${_saved.length} outfits from Firebase');
    notifyListeners();
  }
  
  // Load items from Firestore snapshot
  void _loadItemsFromSnapshot(QuerySnapshot snapshot) {
    debugPrint('[Wardrobe] 📡 Snapshot received with ${snapshot.docs.length} docs');
    _items.clear();
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final photoUrl = data['photoUrl'] as String?;
      final title = data['title'] as String? ?? 'Untitled';
      
      if (photoUrl != null && photoUrl.isNotEmpty) {
        final metadata = {
          'category': data['category'],
          'colors': data['colors'],
          'material': data['material'],
          'style_tags': data['style_tags'],
          'pattern': data['pattern'],
          'warmth': data['warmth'],
          'notes': data['notes'],
          'ai_processed_at': data['ai_processed_at'],
        };
        
        // Check if this item has AI data
        final hasAiData = metadata.values.any((v) => v != null);
        debugPrint('[Wardrobe] 📦 Item ${doc.id}: title=$title, AI_data=$hasAiData');
        if (hasAiData) {
          debugPrint('[Wardrobe]   ✅ Category=${metadata['category']}, Colors=${metadata['colors']}, Material=${metadata['material']}');
        }
        
        final item = WardrobeItem(
          imagePath: photoUrl,
          title: title,
          id: doc.id,
          metadata: metadata,
        );
        _items.add(item);
      }
    }
    
    debugPrint('[Wardrobe] ✅ Loaded ${_items.length} items from Firebase snapshot');
    notifyListeners();
  }

  void selectStyle(String style) {
    if (_selectedStyle == style) return;
    _selectedStyle = style;
    notifyListeners();
  }

  List<WardrobeItem> getItemsByKeys(List<String> keys) {
    debugPrint('[Wardrobe] getItemsByKeys called with keys: $keys');
    debugPrint('[Wardrobe] Total items in wardrobe: ${_items.length}');
    
    final found = <WardrobeItem>[];
    for (var item in _items) {
      debugPrint('[Wardrobe] Checking item id=${item.id}, title=${item.title}');
      if (keys.contains(item.id ?? '')) {
        debugPrint('[Wardrobe] ✅ Found matching item: ${item.title}');
        found.add(item);
      }
    }
    
    debugPrint('[Wardrobe] getItemsByKeys returned ${found.length} items');
    return found;
  }

  Future<void> addItem(WardrobeItem item) async {
    // Items are added via Firebase upload in add_item_screen
    // This is kept for compatibility but Firebase listener will update UI
  }

  Future<void> removeItem(WardrobeItem item) async {
    try {
      debugPrint('[Wardrobe] Removing item: ${item.title}');
      
      if (item.id != null && item.id!.isNotEmpty) {
        debugPrint('[Wardrobe] Deleting Firebase item ID: ${item.id}');
        
        // Delete from Firebase (both Storage and Firestore)
        await _firebaseService.deleteItem(item.id!);
        debugPrint('[Wardrobe] Firebase item deleted successfully');
        
        // Firebase listener will automatically update the UI
      } else {
        debugPrint('[Wardrobe] Item has no ID, cannot delete');
      }
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
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Wardrobe] User not authenticated, cannot save outfit');
      throw Exception('User not authenticated');
    }
    
    try {
      debugPrint('[Wardrobe] saveOutfit called: title=$title, itemKeys=$itemKeys');
      final id = const Uuid().v4();
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('outfits')
          .doc(id)
          .set({
            'id': id,
            'userId': user.uid,
            'title': title,
            'itemKeys': itemKeys,
            'notes': notes,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      debugPrint('[Wardrobe] ✅ Outfit saved to Firebase: $title with ${itemKeys.length} items');
      // Stream listener will automatically update UI
    } catch (e) {
      debugPrint('[Wardrobe] Error saving outfit: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    items.clear();
    saved.clear();
    notifyListeners();
  }

  Future<void> removeSavedById(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Wardrobe] User not authenticated, cannot delete outfit');
      throw Exception('User not authenticated');
    }
    
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('outfits')
          .doc(id)
          .delete();
      
      debugPrint('[Wardrobe] ✅ Outfit deleted from Firebase: $id');
      // Stream listener will automatically update UI
    } catch (e) {
      debugPrint('[Wardrobe] Error deleting outfit: $e');
      rethrow;
    }
  }

  // Diagnostic method to check Firestore data
  Future<void> diagnosticCheckFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Diagnostic] ❌ User not authenticated');
      return;
    }

    try {
      debugPrint('[Diagnostic] 🔍 Checking Firestore data for user ${user.uid}...');
      
      // Check wardrobe items
      final wardrobeSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .get();
      
      debugPrint('[Diagnostic] 📦 Wardrobe items in Firestore: ${wardrobeSnap.docs.length}');
      for (final doc in wardrobeSnap.docs) {
        final data = doc.data();
        debugPrint('[Diagnostic]   - ${doc.id}: title=${data['title']}, has_category=${data['category'] != null}, has_colors=${data['colors'] != null}');
      }
      
      // Check in-memory items
      debugPrint('[Diagnostic] 📱 In-memory items: ${_items.length}');
      for (final item in _items) {
        debugPrint('[Diagnostic]   - ${item.id}: title=${item.title}, metadata=${item.metadata}');
      }
    } catch (e, st) {
      debugPrint('[Diagnostic] ❌ Error: $e\n$st');
    }
  }
}

