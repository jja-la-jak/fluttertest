import 'package:flutter/material.dart';
import 'package:flutter_project/config/environment.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/token_storage.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> _notifications = [];
  final TokenStorage _tokenStorage = TokenStorage();
  bool _isLoading = true;

  Future<void> _fetchNotifications() async {
    final String? accessToken = await _tokenStorage.getAccessToken();

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/notify'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes)); // 한글 디코딩
        if (jsonResponse['isSuccess']) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(jsonResponse['result']);
            _isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("알림 조회 중 오류가 발생했습니다.")),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("알림 조회 실패: $e")),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(int notifyId) async {
    final String? accessToken = await _tokenStorage.getAccessToken();

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${Environment.apiUrl}/notify/$notifyId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes)); // 한글 디코딩
        if (jsonResponse['isSuccess']) {
          setState(() {
            _notifications.removeWhere((notification) => notification['id'] == notifyId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("알림이 삭제되었습니다.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("알림 삭제 중 오류가 발생했습니다.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("알림 삭제 실패: $e")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6C48A),
        elevation: 0,
        title: const Text(
          "알림 목록",
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
            ? Center(
          child: Text(
            "알림이 없습니다.",
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        )
            : ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            // 날짜 포맷 적용
            final createdAt = DateTime.parse(notification['createdAt']);
            final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(createdAt);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE89D63),
                  child: const Icon(Icons.notifications, color: Colors.white),
                ),
                title: Text(
                  notification['content'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "받은 시간: $formattedDate",
                  style: const TextStyle(color: Colors.black54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _deleteNotification(notification['id']);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}