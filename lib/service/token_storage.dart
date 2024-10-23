import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: 'access_token');
  }
}