import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<DateTime?> getAccessTokenExpiresAt() async {
    final expiresAtString = await _secureStorage.read(key: 'access_token_expires_at');
    if (expiresAtString != null) {
      return DateTime.parse(expiresAtString);
    } else {
      return null;
    }
  }

  Future<void> saveAccessToken(String token, DateTime expiresAt) async {
    await _secureStorage.write(key: 'access_token', value: token);
    await _secureStorage.write(key: 'access_token_expires_at', value: expiresAt.toIso8601String());
  }

  Future<void> deleteAccessToken() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'access_token_expires_at');
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: 'refresh_token', value: token);
  }

  Future<bool> isAccessTokenExpired(String accessToken) async {
    final expiresAt = await getAccessTokenExpiresAt();
    if (expiresAt != null) {
      return expiresAt.isBefore(DateTime.now());
    } else {
      return true; // 만료 시간 정보가 없는 경우 토큰이 만료된 것으로 간주
    }
  }

}