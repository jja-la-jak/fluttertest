import 'package:flutter/material.dart';
import 'package:flutter_project/screens/playlist_page.dart';
import 'package:flutter_project/screens/chatting.dart';
import 'package:flutter_project/modules/search_music.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_project/services/token_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_project/screens/youtube_player_screen.dart';
import 'package:flutter_project/screens/ranking.dart';
import 'package:flutter_project/screens/userinfo_page.dart';
import 'package:flutter_project/service/music_service.dart';

class CustomScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onTabTapped;

  const CustomScaffold({
    Key? key,
    required this.body,
    required this.currentIndex,
    required this.onTabTapped,
  }) : super(key: key);

  @override
  State<CustomScaffold> createState() => _CustomScaffoldState();
}

class _CustomScaffoldState extends State<CustomScaffold> {
  static const double _kAppBarHeight = 56.0;
  static const double _kBottomNavBarHeight = 60.0;
  static const double _kIconSize = 36.0;
  static const double _kSearchBarBorderRadius = 20.0;
  static const double _kSearchIconPadding = 8.0;
  DateTime? _lastBackPressTime;


  final TextEditingController _searchController = TextEditingController();
  List<Music> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      final results = await searchMusic(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2D7B6),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_showResults)
            Expanded(
              child: _searchResults.isEmpty && !_isSearching
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final music = _searchResults[index];
                  return ListTile(
                    title: Text(music.title),
                    subtitle: Text(music.artist),
                    trailing: SizedBox(
                      width: 150,  // 조절 가능한 너비
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              '조회수: ${music.viewCount}',
                              textAlign: TextAlign.end,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              await _showAddToPlaylistDialog(context, music);
                              await _increaseViewCount(music.id);
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => YoutubePlayerScreen(youtubeUrl: music.url),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(child: widget.body),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Future<void> _increaseViewCount(int musicId) async {
    try {
      final updatedMusic = await MusicService.increaseViewCount(musicId);
      print('조회수 증가: ${updatedMusic.viewCount}');
    } catch (e) {
      print('조회수 증가 에러: $e');
    }
  }

// 플레이리스트 선택 다이얼로그를 보여주는 메서드
  Future<void> _showAddToPlaylistDialog(BuildContext context, Music music) async {
    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://gnumusic.shop/api/playlists'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['isSuccess']) {
          final playlists = jsonResponse['result']['playlistPreviewList'] as List;

          if (!mounted) return;

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('플레이리스트 선택'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist['name']),
                        onTap: () {
                          Navigator.pop(context);
                          _addMusicToPlaylist(playlist['playlistId'], music.id);
                        },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('취소'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('플레이리스트를 불러오는데 실패했습니다: $e')),
      );
    }
  }

// 플레이리스트에 음악을 추가하는 메서드
  Future<void> _addMusicToPlaylist(int playlistId, int musicId) async {
    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://gnumusic.shop/api/playlists/$playlistId/musics'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'musicId': musicId}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['isSuccess']) {
          //print('musicid: $musicId');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('음악이 플레이리스트에 추가되었습니다')),
          );
        } else {
          String errorMessage;
          switch(jsonResponse['code']) {
            case 'PLAYLIST4001':
              errorMessage = '플레이리스트를 찾을 수 없습니다';
              break;
            case 'MUSIC4001':
              errorMessage = '음악을 찾을 수 없습니다';
              break;
            case 'PLAYLIST4002':
              errorMessage = '이미 플레이리스트에 존재하는 음악입니다';
              break;
            default:
              errorMessage = jsonResponse['message'];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('음악 추가에 실패했습니다: $e')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(_kAppBarHeight),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _buildSearchBar(),
        actions: _buildAppBarActions(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFF6C48A),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Home'),
            onTap: () {
              // Home 페이지로 이동하는 로직 추가
              Navigator.of(context).pop(); // 메뉴 바 닫기
            },
          ),
          // 여기에 추가로 필요한 메뉴 항목 추가
        ],
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(_kSearchBarBorderRadius),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: _performSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '검색',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black54),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _showResults = false;
                });
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserInfoPage()),
          );
        },
        child: _buildCircleAvatarButton('assets/profile.png', 0),
      ),
      _buildCircleAvatarButton('assets/menu.png', 1),
    ];
  }

  Widget _buildCircleAvatarButton(String assetName, int index) {
    return IconButton(
      icon: CircleAvatar(
        radius: 18,
        backgroundImage: AssetImage(assetName),
        backgroundColor: Colors.transparent,
      ),
      onPressed: () {
        if (index == 0) {
          // 프로필 이미지 버튼이 눌렸을 때 실행되는 로직
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserInfoPage()),
          );
        } else if (index == 1) {
          // 메뉴 버튼이 눌렸을 때 실행되는 로직
          Scaffold.of(context).openDrawer();
        }
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return SizedBox(
      height: _kBottomNavBarHeight,
      child: Row(
        children: [
          _buildNavItem(context, 'assets/image/music.png', 0, const Color(0xFFF6C48A)),
          _buildNavItem(context, 'assets/image/chatting.png', 1, const Color(0xFFE89D63)),
          _buildNavItem(context,  'assets/image/rating.png', 2, const Color(0xFFF6C48A)),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String imagePath, int index, Color color) {
    final isSelected = widget.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {  // 선택되지 않았을 때만 동작
            widget.onTabTapped(index);
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const PlaylistPage(),
                  transitionDuration: Duration.zero,  // 애니메이션 시간을 0으로 설정
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            }
            if (index == 1) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const Chatting(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            }
            if (index == 2) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const Ranking(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            }
          }
        },
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                imagePath,
                width: isSelected ? 36 : 24, // 선택되었을 때 크기가 크게 표시
                color: isSelected ? Colors.black : Colors.black54,
              ),
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.black : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

