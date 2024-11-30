import 'package:flutter/material.dart';
import 'package:flutter_project/config/environment.dart';
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

  Future<List<Map<String, dynamic>>> _fetchFromEndpoint(String endpoint, String accessToken) async {
    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        return List<Map<String, dynamic>>.from(jsonResponse['result']['friends'] ?? []);
      }
    }
    return [];
  }

  Future<void> _fetchRequests() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (widget.type == "sent") {
      final friendRequests = await _fetchFromEndpoint(
        '${Environment.apiUrl}/friends/requests',
        accessToken,
      );
      setState(() {
        _requests = friendRequests;
        _isLoading = false;
      });
    } else {
      try {
        final friendRequests = await _fetchFromEndpoint(
          '${Environment.apiUrl}/friends/requests/received',
          accessToken,
        );

        // 플레이리스트 초대는 다른 구조로 오므로 따로 처리
        final response = await http.get(
          Uri.parse('${Environment.apiUrl}/teamPlaylists/invitations/received'),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        List<Map<String, dynamic>> playlistInvitations = [];

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          if (jsonResponse['isSuccess']) {
            // teamPlaylists 리스트를 requests 형태로 변환
            playlistInvitations = (jsonResponse['result']['teamPlaylists'] as List)
                .map((playlist) => {
              'teamPlaylistMemberId': playlist['teamPlaylistMemberId'],
              'teamPlaylist': {
                'teamPlaylistId': playlist['teamPlaylist']['teamPlaylistId']  // 팀 플레이리스트 id 추가
              },
              'user': {
                'name': playlist['teamPlaylist']['name'],
                'email': '에서 온 팀원 초대'
              }
            })
                .toList();
          }
        }

        // 두 리스트를 합치고 날짜순 정렬
        final allRequests = [...friendRequests, ...playlistInvitations];

        setState(() {
          _requests = allRequests;
          _isLoading = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("요청 목록 조회 중 오류가 발생했습니다.")),
        );
        setState(() {
          _isLoading = false;
        });
      }
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
      Uri.parse('${Environment.apiUrl}/friends/requests/$requestId/cancel'),
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

    // 요청을 찾아서 타입 확인
    final request = _requests.firstWhere((req) =>
    (req['id'] == requestId || req['teamPlaylistMemberId'] == requestId));

    final response = await http.patch(
      // id가 있으면 친구 요청, teamPlaylistMemberId가 있으면 플레이리스트 초대
      Uri.parse(request['id'] != null
          ? '${Environment.apiUrl}/friends/requests/$requestId/accept'
          : '${Environment.apiUrl}/teamPlaylists/${request['teamPlaylist']['teamPlaylistId']}/invitations/$requestId/accept'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _requests.removeWhere((req) =>
          (req['id'] == requestId || req['teamPlaylistMemberId'] == requestId));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(request['id'] != null
              ? "친구 요청을 수락했습니다."
              : "플레이리스트 초대를 수락했습니다.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(request['id'] != null
            ? "친구 요청 수락 중 오류가 발생했습니다."
            : "플레이리스트 초대 수락 중 오류가 발생했습니다.")),
      );
    }
  }
  // _refuseRequest 메서드를 다음과 같이 수정합니다
  Future<void> _refuseRequest(int requestId) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    // 요청을 찾아서 타입 확인
    final request = _requests.firstWhere((req) =>
    (req['id'] == requestId || req['teamPlaylistMemberId'] == requestId));

    final response = await http.delete(
      // id가 있으면 친구 요청, teamPlaylistMemberId가 있으면 플레이리스트 초대
      Uri.parse(request['id'] != null
          ? '${Environment.apiUrl}/friends/requests/$requestId/refuse'
          : '${Environment.apiUrl}/teamPlaylists/${request['teamPlaylist']['teamPlaylistId']}/invitations/$requestId/reject'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        setState(() {
          _requests.removeWhere((req) =>
          (req['id'] == requestId || req['teamPlaylistMemberId'] == requestId));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(request['id'] != null
              ? "친구 요청을 거절했습니다."
              : "플레이리스트 초대를 거절했습니다.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(request['id'] != null
            ? "친구 요청 거절 중 오류가 발생했습니다."
            : "플레이리스트 초대 거절 중 오류가 발생했습니다.")),
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
                      onPressed: () => _acceptRequest(request['id'] ?? request['teamPlaylistMemberId']),
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
                      onPressed: () => _refuseRequest(request['id'] ?? request['teamPlaylistMemberId']),
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
