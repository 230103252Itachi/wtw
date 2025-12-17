import 'package:hive/hive.dart';
import 'dart:async';

class AICache {
  static const _boxName = 'ai_cache';
  
  // Stream controller for cache updates
  static final _updateController = StreamController<String>.broadcast();
  
  // Public stream for UI to listen
  static Stream<String> get updates => _updateController.stream;

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
  }

  static dynamic get(String key) {
    if (!Hive.isBoxOpen(_boxName)) return null;
    final box = Hive.box(_boxName);
    return box.get(key);
  }

  static Future<void> put(String key, dynamic value) async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
    final box = Hive.box(_boxName);
    await box.put(key, value);
    // Emit update event
    _updateController.add(key);
  }

  static Future<void> remove(String key) async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
    final box = Hive.box(_boxName);
    await box.delete(key);
    // Emit update event
    _updateController.add(key);
  }
  
  static void dispose() {
    _updateController.close();
  }
}
