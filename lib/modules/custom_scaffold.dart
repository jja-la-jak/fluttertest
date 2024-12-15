import 'package:flutter/material.dart';
import 'package:flutter_project/screens/playlist_page.dart';
import 'package:flutter_project/screens/chatting_page.dart';
import 'package:flutter_project/modules/search_music.dart';
import 'package:flutter_project/screens/notification_page.dart'; // 알림 화면 추가
import 'package:flutter_project/services/token_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_project/screens/youtube_player_screen.dart';
import 'package:flutter_project/screens/ranking_page.dart';
import 'package:flutter_project/screens/userinfo_page.dart';
import 'package:flutter_project/service/music_service.dart';

import '../config/environment.dart';
import '../service/playlist_service.dart';
import '../service/team_playlist_service.dart';

enum PlaylistType { personal, team }

class CustomScaffold extends StatefulWidget {
  static final GlobalKey<CustomScaffoldState> globalKey = GlobalKey(); // GlobalKey 추가
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onTabTapped;
  final Future<void> Function()? onRefresh; // Optional onRefresh callback
  final VoidCallback? refreshNotificationCount; // Callback to refresh notification count

  const CustomScaffold({
    Key? key,
    required this.body,
    required this.currentIndex,
    required this.onTabTapped,
    this.onRefresh,
    this.refreshNotificationCount,
  }) : super(key: key);

  @override
  State<CustomScaffold> createState() => CustomScaffoldState();
}

class CustomScaffoldState extends State<CustomScaffold> {
  PlaylistType _selectedType = PlaylistType.personal;

  static const double _kAppBarHeight = 56.0;
  static const double _kBottomNavBarHeight = 60.0;
  static const double _kIconSize = 36.0;
  static const double _kSearchBarBorderRadius = 20.0;
  static const double _kSearchIconPadding = 8.0;
  DateTime? _lastBackPressTime;
  Map<String, dynamic>? _userInfo;

  final TextEditingController _searchController = TextEditingController();
  List<Music> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  int _unreadNotificationCount = 0; // 읽지 않은 알림 개수
  late PlaylistService _playlistService;
  late TeamPlaylistApiService _teamPlaylistApiService;
  TeamPlaylistCollaborationService? _collaborationService;
  String? _accessToken;



  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _initializeServices();
    fetchUnreadNotificationCount(); // 알림 개수 조회
  }

  // 새로 추가된 초기화 메서드
  Future<void> _initializeServices() async {
    final TokenStorage tokenStorage = TokenStorage();
    _accessToken = await tokenStorage.getAccessToken();

    if (_accessToken != null) {
      setState(() {
        _playlistService = PlaylistService();
        _teamPlaylistApiService = TeamPlaylistApiService(accessToken: _accessToken);
        _collaborationService = TeamPlaylistCollaborationService(accessToken: _accessToken!);
      });
      _fetchUserInfo();
    }
  }


  @override
  void dispose() {
    _searchController.dispose();
    _collaborationService?.dispose();
    super.dispose();
  }

  Future<void> _fetchUserInfo() async {
    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/users/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['isSuccess']) {
          setState(() {
            _userInfo = jsonResponse['result'];
          });
        }
      }
    } catch (e) {
      print('사용자 정보 불러오기 실패: $e');
    }
  }

  Future<void> fetchUnreadNotificationCount() async {
    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/notify/count'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['isSuccess']) {
          setState(() {
            _unreadNotificationCount = jsonResponse['result'];
          });
        }
      }
    } catch (e) {
      print('알림 개수 조회 실패: $e');
    }
  }

  Future<void> performSearchWithQuery(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showResults = true;
      _searchController.text = query; // 검색어 입력란에 자동으로 채우기
    });

    try {
      final results = await searchMusic(query, type: "title"); // 검색 API 호출
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
      body:
      widget.onRefresh != null ?
      RefreshIndicator(child: widget.body, onRefresh: () async {
        if (widget.onRefresh != null) {
          await widget.onRefresh!();
        }
        if (widget.refreshNotificationCount != null) {
          widget.refreshNotificationCount!(); // 알림 개수 갱신 요청
        }
      },) :
      Column(
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
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(music.thumbnail),
                      backgroundColor: Colors.grey[200],
                    ),
                    title: Text(music.title),
                    subtitle: Text("${music.artist} - ${music.viewCount}회 재생"),
                    onTap: () async {  // 여기에 onTap 추가
                      await _increaseViewCount(music.id);
                      Navigator.of(context).push(  // pushReplacement 대신 push 사용
                        MaterialPageRoute(
                          builder: (context) => YoutubePlayerScreen(youtubeUrl: music.url),
                        ),
                      );
                    },
                    trailing: SizedBox(
                      width: 50,  // 조절 가능한 너비
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Expanded(
                          //   child: Text(
                          //     '조회수: ${music.viewCount}',
                          //     textAlign: TextAlign.end,
                          //   ),
                          // ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              await _showAddToPlaylistDialog(context, music);

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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('플레이리스트 선택'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<PlaylistType>(
                    segments: const [
                      ButtonSegment(
                        value: PlaylistType.personal,
                        label: Text('개인 플레이리스트'),
                      ),
                      ButtonSegment(
                        value: PlaylistType.team,
                        label: Text('팀 플레이리스트'),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<PlaylistType> selected) {
                      setState(() {
                        _selectedType = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<dynamic>(
                    future: _selectedType == PlaylistType.personal
                        ? _loadPersonalPlaylists(accessToken)
                        : _loadTeamPlaylists(accessToken),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (!snapshot.hasData || snapshot.data.isEmpty) {
                        return const Text('플레이리스트가 없습니다');
                      }

                      final playlists = snapshot.data;
                      return SizedBox(
                        width: double.maxFinite,
                        height: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];

                            print(playlists.runtimeType);
                            print(index.runtimeType);
                            print(playlist.runtimeType);
                            return ListTile(
                              title: Text(playlist.name),
                              onTap: () {
                                Navigator.pop(context);
                                _selectedType == PlaylistType.personal
                                    ? _addMusicToPlaylist(playlist.playlistId, music.id)
                                    : _addMusicToTeamPlaylist(playlist.teamPlaylistId, music.id);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
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
      },
    );
  }

  Future<List<dynamic>> _loadPersonalPlaylists(String accessToken) async {
    try {
      final playlistPreViewList = await _playlistService.getPlaylistPreViewList(accessToken);
      return playlistPreViewList.playlistPreviewList;
    } catch (e) {
      throw Exception('Failed to load playlists: $e');
    }
  }

  Future<List<dynamic>> _loadTeamPlaylists(String accessToken) async {
    try {
      final teamPlaylistPreViewList = await _teamPlaylistApiService.getTeamPlaylistPreViewList();
      return teamPlaylistPreViewList.teamPlaylistPreviewList;
    } catch (e) {
      throw Exception('Failed to load playlists: $e');
    }
  }

  Future<void> _addMusicToTeamPlaylist(int teamPlaylistId, int musicId) async {
    final TokenStorage tokenStorage = TokenStorage();
    final String? accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      _collaborationService ??= TeamPlaylistCollaborationService(accessToken: accessToken);
      await _collaborationService!.addTeamPlaylistMusics(teamPlaylistId, musicId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음악이 팀 플레이리스트에 추가되었습니다')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('음악 추가에 실패했습니다: $e')),
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
        Uri.parse('${Environment.apiUrl}/playlists/$playlistId/musics'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'musicId': musicId}),
      );

      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        if (jsonResponse['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('음악이 플레이리스트에 추가되었습니다')),
          );
        }
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
        backgroundColor: Color(0xFFF6C48A),
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
      Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationPage()),
              );
            },
          ),
          if (_unreadNotificationCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text(
                  '$_unreadNotificationCount',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      IconButton(
        icon: _userInfo?.containsKey('profileImage') == true && _userInfo!['profileImage'] != null
            ? CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(_userInfo!['profileImage']),
        )
            : const CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage('assets/profile.png'),
          backgroundColor: Colors.transparent,
        ),
        onPressed: () {
          if (widget.currentIndex != 3) { // UserInfoPage가 아닐 때만 업데이트
            widget.onTabTapped(3); // UserInfoPage의 인덱스로 변경
            // UserInfoPage로 이동
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation,
                    secondaryAnimation) => const UserInfoPage(),
                transitionDuration: Duration.zero, // 애니메이션 시간을 0으로 설정
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
      ),
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
