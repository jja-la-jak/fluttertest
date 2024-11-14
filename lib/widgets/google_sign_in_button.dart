import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_project/modules/api_response.dart';
import 'package:flutter_project/service/user_service.dart';

class GoogleSignInButton extends StatelessWidget {
  final Function onSignInSuccess;

  GoogleSignInButton({required this.onSignInSuccess});

  final GoogleSignIn _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: '439295586620-c061rcbgi4voic25alf313bkfg1epah7.apps.googleusercontent.com'
  );
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> _handleSignIn(BuildContext context) async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('clientId ${googleUser}');

      if (googleUser != null) {
        if (googleUser.serverAuthCode == null) {
          throw Exception('Server auth code is null');
        }

        print(googleUser);

        final response = await http.post(
          Uri.parse('https://gnumusic.shop/api/auth/google'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'name': googleUser.displayName,
            'email': googleUser.email,
            'providerId': googleUser.id,
            'authCode': googleUser.serverAuthCode
          }),
        );

        final ApiResponse<Map<String, dynamic>> apiResponse = ApiResponse.fromJson(
          jsonDecode(response.body),
              (json) => json as Map<String, dynamic>,
        );

        if (apiResponse.isSuccess) {
          final String accessToken = apiResponse.result['accessToken'];
          final String refreshToken = apiResponse.result['refreshToken'];
          await _secureStorage.deleteAll();
          await _secureStorage.write(key: 'access_token', value: accessToken);
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);

          onSignInSuccess();
        } else {
          print("error message : ${apiResponse.message}");
          print("error code : ${apiResponse.code}");
          if (apiResponse.code == 'TOKEN4003') {
            throw TokenExpiredException('Refresh token expired');
          }
          throw Exception(apiResponse.code);
        }
      }
    } catch (error) {
      print('Sign in error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 중 오류가 발생했습니다: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: Text('Google로 로그인'),
      onPressed: () => _handleSignIn(context),
    );
  }
}