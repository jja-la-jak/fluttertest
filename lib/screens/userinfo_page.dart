import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_project/modules/custom_scaffold.dart';
import 'package:flutter_project/services/token_storage.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({Key? key}) : super(key: key);

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  Map<String, dynamic> _userInfo = {};
  int _currentIndex = 3; // 사용자 정보 페이지에 해당하는 인덱스

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken != null) {
      final response = await http.get(
        Uri.parse('https://gnumusic.shop/api/users/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['isSuccess']) {
          setState(() {
            _userInfo = jsonResponse['result'];
          });
        } else {
          // 서버 에러 처리
          print('Error: ${jsonResponse['code']} - ${jsonResponse['message']}');
        }
      } else {
        // HTTP 에러 처리
        print('HTTP Error: ${response.statusCode}');
      }
    } else {
      // 액세스 토큰 없음 처리
      print('No access token found');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // TODO: 여기에 각 탭에 대한 네비게이션 로직을 추가하세요
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      currentIndex: _currentIndex,
      onTabTapped: _onTabTapped,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_userInfo['profileImage'] != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_userInfo['profileImage']),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_userInfo['name']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_userInfo['email']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}