import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/wardrobe_item.dart';
import '../models/outfit.dart';
import 'package:uuid/uuid.dart';

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

  // В WardrobeModel
  List<WardrobeItem> getItemsByKeys(List<String> keys) {
    final found = <WardrobeItem>[];

    for (var k in keys) {
      // 1) Попробуем найти по Hive key (key может быть int или String)
      try {
        final byKey = items.firstWhere((it) {
          final keyStr = it.key?.toString() ?? '';
          return keyStr == k;
        });
        found.add(byKey);
        continue; // нашли — переходим к следующему ключу
      } catch (e) {
        // ничего — не найден по key
      }

      // 2) Попробуем найти по imagePath
      try {
        final byPath = items.firstWhere((it) => it.imagePath == k);
        found.add(byPath);
        continue;
      } catch (e) {
        // тоже не найден — пропускаем
      }
    }

    return found;
  }

  Future<void> addItem(WardrobeItem item) async {
    await _box.add(item);
    notifyListeners();
  }

  Future<void> removeItem(WardrobeItem item) async {
    await item.delete();
    notifyListeners();
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
}
