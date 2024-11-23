import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/token_storage.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final TokenStorage _tokenStorage = TokenStorage();
  String _searchType = 'name'; // Default search type

  final List<DropdownMenuItem<String>> _searchOptions = [
    DropdownMenuItem(value: 'name', child: Text('이름')),
    DropdownMenuItem(value: 'nickname', child: Text('닉네임')),
    DropdownMenuItem(value: 'email', child: Text('이메일')),
  ];

  Future<void> _searchUsers(String query) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    final response = await http.get(
      Uri.parse('https://gnumusic.shop/api/users/search?type=$_searchType&query=$query'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(jsonResponse['result']);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("검색 중 오류가 발생했습니다.")),
      );
    }
  }

  Future<void> _sendFriendRequest(int userId) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('https://gnumusic.shop/api/friends/requests'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("친구 요청이 전송되었습니다.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("친구 요청 전송 중 오류가 발생했습니다.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6C48A),
        elevation: 0,
        title: const Text(
          "유저 검색",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6C48A), Color(0xFFF2D7B6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // 드롭다운 메뉴
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _searchType,
                      items: _searchOptions,
                      onChanged: (String? newValue) {
                        setState(() {
                          _searchType = newValue!;
                        });
                      },
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 검색창
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "검색어를 입력하세요",
                        hintStyle: const TextStyle(color: Colors.black54),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: Colors.black87),
                          onPressed: () => _searchUsers(_searchController.text),
                        ),
                      ),
                      onSubmitted: _searchUsers,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                child: Text(
                  "검색된 유저가 없습니다",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE89D63),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        user['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user['email']),
                      trailing: ElevatedButton(
                        onPressed: () => _sendFriendRequest(user['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE89D63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("친구 요청"),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
