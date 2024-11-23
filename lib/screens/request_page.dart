import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/token_storage.dart';

class RequestPage extends StatefulWidget {
  final String type; // "sent" or "received"

  const RequestPage({Key? key, required this.type}) : super(key: key);

  @override
  _RequestPageState createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  List<Map<String, dynamic>> _requests = [];
  final TokenStorage _tokenStorage = TokenStorage();
  bool _isLoading = true;

  Future<void> _fetchRequests() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    final endpoint = widget.type == "sent"
        ? 'https://gnumusic.shop/api/friends/requests'
        : 'https://gnumusic.shop/api/friends/requests/received';

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(jsonResponse['result']['friends']);
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("요청 목록 조회 중 오류가 발생했습니다.")),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelRequest(int requestId) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    final response = await http.delete(
      Uri.parse('https://gnumusic.shop/api/friends/requests/$requestId/cancel'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _requests.removeWhere((request) => request['id'] == requestId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("요청이 성공적으로 취소되었습니다.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("요청 취소 중 오류가 발생했습니다.")),
      );
    }
  }

  Future<void> _acceptRequest(int requestId) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    final response = await http.patch(
      Uri.parse('https://gnumusic.shop/api/friends/requests/$requestId/accept'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _requests.removeWhere((request) => request['id'] == requestId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("친구 요청을 수락했습니다.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("친구 요청 수락 중 오류가 발생했습니다.")),
      );
    }
  }

  Future<void> _refuseRequest(int requestId) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    final response = await http.delete(
      Uri.parse('https://gnumusic.shop/api/friends/requests/$requestId/refuse'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _requests.removeWhere((request) => request['id'] == requestId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("친구 요청을 거절했습니다.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("친구 요청 거절 중 오류가 발생했습니다.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6C48A),
        elevation: 0,
        title: Text(
          widget.type == "sent" ? "보낸 요청" : "받은 요청",
          style: const TextStyle(
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
            ? Center(
          child: Text(
            widget.type == "sent" ? "보낸 요청이 없습니다." : "받은 요청이 없습니다.",
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        )
            : ListView.builder(
          itemCount: _requests.length,
          itemBuilder: (context, index) {
            final request = _requests[index];
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
                  request['user']['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(request['user']['email']),
                trailing: widget.type == "sent"
                    ? ElevatedButton(
                  onPressed: () => _cancelRequest(request['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF44336),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("취소"),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _acceptRequest(request['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("수락"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _refuseRequest(request['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("거절"),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
