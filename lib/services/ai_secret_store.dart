import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiSecretStoreProvider = Provider<AiSecretStore>((ref) {
  return AiSecretStore();
});

class AiSecretStore {
  AiSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _apiKey = 'ai_provider_api_key';
  final FlutterSecureStorage _storage;

  Future<String?> readApiKey() => _storage.read(key: _apiKey);

  Future<void> writeApiKey(String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: _apiKey);
    } else {
      await _storage.write(key: _apiKey, value: value.trim());
    }
  }

  Future<void> deleteApiKey() => _storage.delete(key: _apiKey);
}
