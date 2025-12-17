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
  
  void _setupAuthListener() {
    _auth.authStateChanges().listen((user) {
      if (user != null && user.uid != _currentUserId) {
        _currentUserId = user.uid;
        _resetAndInitialize();
      } else if (user == null) {
        _currentUserId = null;
        _clearAllData();
      }
    });
  }
  
  void _resetAndInitialize() {
    _clearAllData();
    _initializeFirebaseListener();
    _initializeOutfitsListener();
  }
  
  void _clearAllData() {
    _itemsSubscription?.cancel();
    _outfitsSubscription?.cancel();
    _items.clear();
    _saved.clear();
    notifyListeners();
  }
  
  void _initializeFirebaseListener() {
    final user = _auth.currentUser;
    if (user != null) {
      _itemsSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .snapshots()
          .listen((snapshot) {
        _loadItemsFromSnapshot(snapshot);
      }, onError: (e) {
        return;
      });
    }
  }
  
  void _initializeOutfitsListener() {
    final user = _auth.currentUser;
    if (user != null) {
      _outfitsSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('outfits')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _loadOutfitsFromSnapshot(snapshot);
      }, onError: (e) {
        return;
      });
    }
  }
  
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
    
    notifyListeners();
  }
  
  void _loadItemsFromSnapshot(QuerySnapshot snapshot) {

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
        
        final item = WardrobeItem(
          imagePath: photoUrl,
          title: title,
          id: doc.id,
          metadata: metadata,
        );
        _items.add(item);
      }
    }
    
    notifyListeners();
  }

  void selectStyle(String style) {
    if (_selectedStyle == style) return;
    _selectedStyle = style;
    notifyListeners();
  }

  List<WardrobeItem> getItemsByKeys(List<String> keys) {
    final found = <WardrobeItem>[];
    for (var item in _items) {
      if (keys.contains(item.id ?? '')) {
        found.add(item);
      }
    }
    
    return found;
  }

  Future<void> addItem(WardrobeItem item) async {
  }

  Future<void> removeItem(WardrobeItem item) async {
    try {
      if (item.id != null && item.id!.isNotEmpty) {
        await _firebaseService.deleteItem(item.id!);
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
      throw Exception('User not authenticated');
    }
    
    try {
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
      
    } catch (e) {
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
      throw Exception('User not authenticated');
    }
    
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('outfits')
          .doc(id)
          .delete();
      
    } catch (e) {
    }
  }

  Future<void> diagnosticCheckFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .get();
      
    } catch (e) {
      return;
    }
  }
}

