import 'package:flutter/material.dart';
import 'package:flutter_project/modules/custom_scaffold.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/token_storage.dart';
import 'youtube_player_screen.dart';

class Ranking extends StatefulWidget {
  const Ranking({Key? key}) : super(key: key);

  @override
  _RankingState createState() => _RankingState();
}

class _RankingState extends State<Ranking> {
  int _currentIndex = 2;
  String _selectedDuration = '30'; // 기본값: 30일
  List<Map<String, dynamic>> _rankingList = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  final List<DropdownMenuItem<String>> _durationOptions = [
    DropdownMenuItem(value: '7', child: Text('7일')),
    DropdownMenuItem(value: '30', child: Text('30일')),
    DropdownMenuItem(value: '365', child: Text('365일')),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRanking(); // 초기 데이터 로드
  }

  Future<void> _fetchRanking() async {
    setState(() {
      _isLoading = true;
    });

    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("토큰이 없습니다. 다시 로그인하세요.")),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://gnumusic.shop/api/musicLogs/recentLog?date=$_selectedDuration'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes)); // 한글 디코딩
        if (jsonResponse['isSuccess']) {
          setState(() {
            _rankingList = List<Map<String, dynamic>>.from(jsonResponse['result']).take(100).toList();
            _isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("랭킹 데이터를 가져오는 중 오류가 발생했습니다.")),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("데이터 로드 실패: $e")),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      currentIndex: _currentIndex,
      onTabTapped: _onTabTapped,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드롭다운 메뉴
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '랭킹 기간 선택',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: _selectedDuration,
                      items: _durationOptions,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDuration = newValue!;
                        });
                        _fetchRanking(); // 기간 변경 시 데이터 로드
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 랭킹 리스트
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _rankingList.isEmpty
                    ? const Center(child: Text("랭킹 데이터가 없습니다."))
                    : Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _rankingList.length,
                    itemBuilder: (context, index) {
                      final music = _rankingList[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(music['url']),
                            backgroundColor: Colors.grey[200],
                          ),
                          title: Text(music['title']),
                          subtitle: Text('아티스트: ${music['artist']}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '+${music['viewsIncrement']}',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('총 조회수: ${music['viewCount']}'),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YoutubePlayerScreen(
                                  youtubeUrl: music['url'],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 부유 버튼
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "toTop",
                  onPressed: _scrollToTop,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.arrow_upward, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "toBottom",
                  onPressed: _scrollToBottom,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
