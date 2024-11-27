import 'package:flutter/material.dart';
import 'package:flutter_project/config/environment.dart';
import 'package:flutter_project/screens/request_page.dart';
import 'package:flutter_project/screens/search_page.dart';
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
  List<Map<String, dynamic>> _friendsList = [];
  bool _isLoadingFriends = true;
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _getFriendsList();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );
  }

  void _navigateToRequests(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RequestPage(type: type)),
    );
  }

  Future<void> _getUserInfo() async {
    try {
      final TokenStorage tokenStorage = TokenStorage();
      final String? accessToken = await tokenStorage.getAccessToken();

      if (accessToken != null) {
        final response = await http.get(
          Uri.parse('${Environment.apiUrl}/users/me'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          if (jsonResponse['isSuccess']) {
            setState(() {
              _userInfo = jsonResponse['result'];
            });
          }
        }
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
  }

  Future<void> _getFriendsList() async {
    try {
      final TokenStorage tokenStorage = TokenStorage();
      final String? accessToken = await tokenStorage.getAccessToken();

      if (accessToken != null) {
        final response = await http.get(
          Uri.parse('${Environment.apiUrl}/friends'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          if (jsonResponse['isSuccess']) {
            setState(() {
              _friendsList = List<Map<String, dynamic>>.from(
                  jsonResponse['result']['friends']);
              _isLoadingFriends = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error getting friends list: $e');
    }
  }

  Future<void> _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final TokenStorage tokenStorage = TokenStorage();

        // 토큰 삭제
        await tokenStorage.deleteAccessToken();
        await tokenStorage.deleteRefreshToken();

        if (!mounted) return;

        // 로그인 페이지로 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/splash_screen',
              (route) => false,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그아웃 중 오류가 발생했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteFriend(int friendId) async {
    try {
      final TokenStorage tokenStorage = TokenStorage();
      final String? accessToken = await tokenStorage.getAccessToken();

      if (accessToken != null) {
        print(friendId);
        final response = await http.delete(
          Uri.parse('${Environment.apiUrl}/friends'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'userId': friendId}),
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          if (jsonResponse['isSuccess']) {
            setState(() {
              _friendsList.removeWhere((friend) => friend['user']['id'] == friendId);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('친구가 삭제되었습니다')),
            );
          }
        } else {
          throw Exception('삭제 요청 실패');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('친구 삭제 중 오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
        key: CustomScaffold.globalKey,
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
        body: RefreshIndicator(
          onRefresh: () async {
            await _getUserInfo();
            await _getFriendsList();
            // CustomScaffold의 알림 개수 업데이트 호출
            CustomScaffold.globalKey.currentState?.fetchUnreadNotificationCount();
          },
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6C48A), Color(0xFFF2D7B6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 유저 정보 표시
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(
                            _userInfo['profileImage'] ?? ''),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userInfo['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _userInfo['email'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 로그아웃 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "로그아웃",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 검색, 요청 기능 버튼들
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _navigateToSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE89D63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("유저 검색"),
                      ),
                      ElevatedButton(
                        onPressed: () => _navigateToRequests("sent"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE89D63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("보낸 요청"),
                      ),
                      ElevatedButton(
                        onPressed: () => _navigateToRequests("received"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE89D63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("받은 요청"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 친구 목록 제목
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "친구 목록",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 친구 리스트 (스크롤 가능)
                  Expanded(
                    child: _isLoadingFriends
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                      itemCount: _friendsList.length,
                      itemBuilder: (context, index) {
                        final friend = _friendsList[index];
                        return Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE89D63),
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              friend['user']['name'],
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              friend['user']['email'],
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.settings),
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  final bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('친구 삭제'),
                                        content: const Text('정말로 친구를 삭제하시겠습니까?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('삭제'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    await _handleDeleteFriend(friend['user']['id']);
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('삭제', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
    );
  }
}