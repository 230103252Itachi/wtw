import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OpenAIKeyStore {
  static final _storage = FlutterSecureStorage();
  static const _key = 'openai_api_key';

  static Future<void> saveKey(String apiKey) =>
      _storage.write(key: _key, value: apiKey);

  static Future<String?> getKey() => _storage.read(key: _key);

  static Future<void> deleteKey() => _storage.delete(key: _key);
}
