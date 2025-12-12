import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/models/wardrobe_model.dart';
import 'package:flutter/widgets.dart';

class Outfit {
  final String id;
  final String title;
  final List<String> itemKeys;
  final String notes;
  final String createdAtIso;

  Outfit({
    required this.id,
    required this.title,
    required this.itemKeys,
    required this.notes,
    required this.createdAtIso,
  });

  /// 🎯 Новый getter — позволяет использовать outfit.items как раньше
  List<WardrobeItem> get items {
    try {
      final wardrobe = WardrobeModel.instance; // singleton-provider (см. ниже)
      return wardrobe.getItemsByKeys(itemKeys);
    } catch (e) {
      debugPrint("[Outfit] items getter error: $e");
      return [];
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'itemKeys': itemKeys,
      'notes': notes,
      'createdAt': createdAtIso,
    };
  }

  factory Outfit.fromMap(Map<String, dynamic> m) {
    return Outfit(
      id: m['id']?.toString() ?? DateTime.now().toIso8601String(),
      title: m['title'] ?? 'Outfit',
      itemKeys: List<String>.from(m['itemKeys'] ?? []),
      notes: m['notes'] ?? '',
      createdAtIso: m['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
