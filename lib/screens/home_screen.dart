import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_project/screens/login_screen.dart';
import 'package:flutter_project/service/user_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final UserService _userService = UserService();

  Map<String, dynamic> _userInfo = {};
  bool _isLoading = false;

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userInfo = await _userService.getUserInfo();
      setState(() {
        _userInfo = userInfo;
        _isLoading = false;
      });
    } on TokenExpiredException {
      print('Refresh token expired. Redirecting to login screen.');
      await _handleSignOut();
    } catch (e) {
      print('Error loading user info: $e');
      setState(() {
        _isLoading = false;
        _userInfo = {'error': 'Failed to load user info'};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사용자 정보를 불러오는데 실패했습니다: $e')),
      );
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _googleSignIn.signOut();
      await _secureStorage.deleteAll();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (error) {
      print('Sign out error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 중 오류가 발생했습니다: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('홈'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('환영합니다!', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _loadUserInfo,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('사용자 정보 불러오기'),
            ),
            SizedBox(height: 20),
            if (_userInfo.isNotEmpty && _userInfo['error'] == null) ...[
              Text('이름: ${_userInfo['name'] ?? 'N/A'}'),
              Text('Provider ID: ${_userInfo['providerId'] ?? 'N/A'}'),
              Text('Provider: ${_userInfo['provider'] ?? 'N/A'}'),
            ] else if (_userInfo['error'] != null) ...[
              Text(_userInfo['error'], style: TextStyle(color: Colors.red)),
            ],
            SizedBox(height: 20),
            Text('여기에 음악 추천 기능을 구현하세요.'),
          ],
        ),
      ),
    );
  }
}