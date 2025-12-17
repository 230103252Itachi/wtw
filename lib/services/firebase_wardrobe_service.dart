import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class FirebaseWardrobeService {
  FirebaseWardrobeService._();
  static final FirebaseWardrobeService instance = FirebaseWardrobeService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<String> uploadItemWithPhoto({
    required File photoFile,
    required String category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final itemId = _uuid.v4();

    try {
      final photoRef = _storage.ref().child('users/${user.uid}/items/$itemId/photo.jpg');
      
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
      } catch (e) {
        return itemId;
      }

      return itemId;
    } catch (e) {
      throw Exception('Failed to upload item: $e');
    }
  }

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

  Future<void> updateItemWithAIData(
    String itemId,
    Map<String, dynamic> aiData,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
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

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wardrobe')
          .doc(itemId);

      await docRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteItem(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final itemData = await fetchItem(itemId);
      if (itemData != null && itemData['storagePath'] != null) {
        await _storage.ref(itemData['storagePath']).delete();
      }

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
