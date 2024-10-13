import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class UserInfoPage extends StatefulWidget {
  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await getUserInfo();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

Future<void> getUserInfo() async {
  final response = await http.get(
    Uri.parse('https://gnumusic.shop/api/users/me'),
    //headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 200) {
    final jsonResponse = jsonDecode(response.body);
    if (jsonResponse['isSuccess']) {
      setState(() {
        _userInfo = jsonResponse['result'];
      });
    } else {
      String errorMessage = '알 수 없는 오류가 발생했습니다.';
      switch(jsonResponse['code']) {
        case 'TOKEN4001':
        case 'TOKEN4002':
          errorMessage = '인증에 실패했습니다. 다시 로그인해주세요.';
          break;
        case 'MEMBER4001':
          errorMessage = '사용자 정보를 찾을 수 없습니다.';
          break;
      }
      throw Exception(errorMessage);
    }
  } else {
    throw Exception('서버 오류: ${response.statusCode}');
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('내 정보'),
    ),
    body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : _buildUserInfoView(),
  );
}

Widget _buildUserInfoView() {
  return SingleChildScrollView(
    padding: EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: _userInfo!['profileImage'] != null
                ? NetworkImage(_userInfo!['profileImage'])
                : null,
            child: _userInfo!['profileImage'] == null
                ? Icon(Icons.person, size: 50)
                : null,
          ),
        ),
        SizedBox(height: 20),
        _infoTile('이름', _userInfo!['name']),
        _infoTile('닉네임', _userInfo!['nickname']),
        _infoTile('이메일', _userInfo!['email']),
        SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: _fetchUserInfo,
            child: Text('정보 새로고침'),
          ),
        ),
      ],
    ),
  );
}

Widget _infoTile(String title, String? value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(value ?? '정보 없음'),
        Divider(),
      ],
    ),
  );
}
}