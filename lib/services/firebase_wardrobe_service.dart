import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class FirebaseWardrobeService {
  FirebaseWardrobeService._();
  static final FirebaseWardrobeService instance = FirebaseWardrobeService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Upload item with photo to Firebase
  Future<String> uploadItemWithPhoto({
    required File photoFile,
    required String category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[Firebase] User not authenticated');
      throw Exception('User not authenticated');
    }

    debugPrint('[Firebase] Starting upload for user: ${user.uid}');

    // Generate unique ID for the item
    final itemId = _uuid.v4();
    debugPrint('[Firebase] Generated itemId: $itemId');

    try {
      debugPrint('[Firebase] Uploading photo to Storage...');
      
      // Upload photo to Firebase Storage
      final photoRef = _storage.ref().child('users/${user.uid}/items/$itemId/photo.jpg');
      debugPrint('[Firebase] Storage path: ${photoRef.fullPath}');
      
      final uploadTask = await photoRef.putFile(
        photoFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'itemId': itemId,
            'category': category,
          },
        ),
      );
      final photoUrl = await uploadTask.ref.getDownloadURL();
      
      debugPrint('[Firebase] Photo uploaded successfully. URL: $photoUrl');

      debugPrint('[Firebase] Saving metadata to Firestore...');
      
      // Save item metadata to Firestore
      try {
        await _firestore.collection('users').doc(user.uid).collection('wardrobe').doc(itemId).set({
          'id': itemId,
          'userId': user.uid,
          'title': category,
          'photoUrl': photoUrl,
          'storagePath': photoRef.fullPath,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[Firebase] ✅ Metadata saved successfully');
      } catch (e, st) {
        debugPrint('[Firebase] ❌ Error saving metadata: $e\n$st');
        // Don't rethrow - we still want to return itemId so AI processing can start
        // The Stream listener will eventually get the data
      }

      debugPrint('[Firebase] ✅ Returning itemId: $itemId');
      return itemId;
    } catch (e, st) {
      debugPrint('[Firebase] ❌ Upload error: $e\n$st');
      throw Exception('Failed to upload item: $e');
    }
  }

  // Fetch all items for current user from Firebase
  Future<List<Map<String, dynamic>>> fetchUserItems() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  // Fetch a single item
  Future<Map<String, dynamic>?> fetchItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .doc(itemId)
          .get();

      return doc.data();
    } catch (e) {
      throw Exception('Failed to fetch item: $e');
    }
  }

  // Update item with AI-generated characteristics
  Future<void> updateItemWithAIData(
    String itemId,
    Map<String, dynamic> aiData,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      debugPrint('[Firebase] 🤖 Updating item $itemId with AI data for user ${user.uid}');
      debugPrint('[Firebase]   Raw AI Data: $aiData');
      
      // Extract only AI fields we want to store with proper defaults
      final updateData = {
        'category': aiData['category'] ?? 'Unknown',
        'colors': aiData['colors'] ?? ['neutral'],
        'material': aiData['material'] ?? 'Unknown',
        'style_tags': aiData['style_tags'] ?? [],
        'pattern': aiData['pattern'] ?? 'Unknown',
        'warmth': aiData['warmth'] ?? 'Unknown',
        'notes': aiData['notes'] ?? '',
        'ai_processed_at': FieldValue.serverTimestamp(),
      };

      debugPrint('[Firebase]   Processed data: $updateData');
      
      // Update the Firestore document
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .doc(itemId);
      
      debugPrint('[Firebase]   Firestore path: users/${user.uid}/wardrobe/$itemId');

      // Use set with merge to ensure document is updated even if it doesn't exist yet
      await docRef.set(updateData, SetOptions(merge: true));
      
      debugPrint('[Firebase] ✅ Item $itemId updated with AI data successfully');
    } catch (e, st) {
      debugPrint('[Firebase] ❌ Error updating item with AI data: $e\n$st');
      rethrow;
    }
  }

  // Delete item and its photo
  Future<void> deleteItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get item data to find storage path
      final itemData = await fetchItem(itemId);
      if (itemData != null && itemData['storagePath'] != null) {
        // Delete photo from Storage
        await _storage.ref(itemData['storagePath']).delete();
      }

      // Delete document from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .doc(itemId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  // Update item metadata
  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .doc(itemId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  // Stream of user items for real-time updates
  Stream<List<Map<String, dynamic>>> streamUserItems() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('wardrobe')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
