import 'package:hive/hive.dart';

class AICache {
  static const _boxName = 'ai_cache';

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
  }

  static Future<void> remove(String key) async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
    final box = Hive.box(_boxName);
    await box.delete(key);
  }
}
