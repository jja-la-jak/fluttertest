import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_project/modules/api_response.dart';

class UserService {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final String _baseUrl = 'https://gnumusic.shop';

  Future<String> _getAccessToken() async {
    return await _secureStorage.read(key: 'access_token') ?? '';
  }

  Future<String> _getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token') ?? '';
  }

  Future<void> _saveAccessToken(String token) async {
    await _secureStorage.write(key: 'access_token', value: token);
  }

  Future<String> _refreshAccessToken(String refreshToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/reissue/access-token'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $refreshToken',
      },
    );
    print('reissue access token response');

    final ApiResponse<Map<String, dynamic>> apiResponse = ApiResponse.fromJson(
      json.decode(response.body),
          (json) => json as Map<String, dynamic>,
    );
    print(apiResponse.result);

    if (apiResponse.isSuccess) {
      final String newAccessToken = apiResponse.result['accessToken'];
      await _saveAccessToken(newAccessToken);
      return newAccessToken;
    } else {
      print("error message : ${apiResponse.message}");
      print("error code : ${apiResponse.code}");
      if (apiResponse.code == 'TOKEN4003') {
        throw TokenExpiredException('Refresh token expired');
      }
      throw Exception(apiResponse.code);
    }
  }

  Future<Map<String, dynamic>> getUserInfo() async {
    String accessToken = await _getAccessToken();

    try {
      return await _fetchUserInfo(accessToken);
    } catch (e) {
      if (e.toString().contains('TOKEN4001')) {
        // 액세스 토큰 만료 시 리프레시
        final refreshToken = await _getRefreshToken();
        try {
          accessToken = await _refreshAccessToken(refreshToken);
          return await _fetchUserInfo(accessToken);
        } on TokenExpiredException {
          // 리프레시 토큰도 만료된 경우
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchUserInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/userInfo'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $accessToken',
      },
    );

    final ApiResponse<Map<String, dynamic>> apiResponse = ApiResponse.fromJson(
      json.decode(utf8.decode(response.bodyBytes)),
          (json) => json as Map<String, dynamic>,
    );

    if (apiResponse.isSuccess) {
      return apiResponse.result;
    } else if (apiResponse.code == 'TOKEN4001') {
      throw Exception('TOKEN4001');
    } else {
      throw Exception(apiResponse.message);
    }
  }
}

class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException(this.message);
}