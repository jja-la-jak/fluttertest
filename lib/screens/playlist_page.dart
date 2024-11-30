import 'dart:async';

import 'package:flutter/material.dart';
import '../modules/custom_scaffold.dart';
import '../modules/playlist_models.dart';
import '../modules/team_playlist_models.dart';
import '../service/team_playlist_service.dart';
import '../service/playlist_service.dart';
import '../services/token_storage.dart';
import '../screens/team_management_page.dart';
import '../screens/youtube_player_screen.dart';
import 'package:flutter/services.dart' show HapticFeedback;

enum PlaylistType {personal, team}
PlaylistType _selectedType = PlaylistType.personal;
int? _selectedPlaylistId;
List<PlaylistPreViewDto> _playlists = [];
List<TeamPlaylistPreViewDto> _teamPlaylists = [];  // 팀 플레이리스트 목록 추가

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  int _currentIndex = 0;
  String? accessToken;
  bool _isLoading = false;
  bool _isEditMode = false;
  final Set<int> _selectedMusicIds = {};
  final TokenStorage _tokenStorage = TokenStorage();
  final PlaylistService _playlistService = PlaylistService();
  late TeamPlaylistApiService _teamPlaylistApiService; // 팀 플레이리스트 서비스 추가
  late TeamPlaylistCollaborationService _collaborationService;
  late Future<List<PlaylistMusicDto>> _playlistMusicsFuture;
  late Future<List<TeamPlaylistMusicDto>> _teamPlaylistMusicsFuture;  // 팀 플레이리스트 음악 Future 추가
  StreamSubscription? _musicStreamSubscription;

  @override
  void initState() {
    super.initState();
    _teamPlaylistApiService = TeamPlaylistApiService();
    _initializeServices();
    _playlistMusicsFuture = Future.value([]);
    _teamPlaylistMusicsFuture = Future.value([]);
  }

  void _loadPlaylistMusics() {
    if (_selectedPlaylistId != null && accessToken != null) {
      _playlistMusicsFuture = _playlistService.getPlaylistMusics(
          accessToken!,
          _selectedPlaylistId!
      );
    }
  }

  String getPlaylistName() {
    try {
      if (_selectedType == PlaylistType.personal && _playlists.isNotEmpty) {
        final playlist = _playlists.firstWhere(
              (p) => p.playlistId == _selectedPlaylistId,
          orElse: () => _playlists[0],
        );
        return playlist.name;
      } else if (_selectedType == PlaylistType.team && _teamPlaylists.isNotEmpty) {
        final playlist = _teamPlaylists.firstWhere(
              (p) => p.teamPlaylistId == _selectedPlaylistId,
          orElse: () => _teamPlaylists[0],
        );
        return playlist.name;
      }
      return '플레이리스트';  // 기본값 반환
    } catch (e) {
      return '플레이리스트';  // 에러 발생시 기본값 반환
    }
  }

  void _loadTeamPlaylistMusics() {
    if (_selectedPlaylistId != null) {
      // 새로운 플레이리스트가 선택되었을 때 웹소켓 연결 설정
      _setupTeamPlaylistConnection(_selectedPlaylistId!);

      setState(() {
        _teamPlaylistMusicsFuture = _teamPlaylistApiService.getTeamPlaylistMusics(_selectedPlaylistId!);
      });
    }
  }

  Future<void> _setupTeamPlaylistConnection(int playlistId) async {
    await _musicStreamSubscription?.cancel();

    await _collaborationService.ensureStompConnection(playlistId);

    _musicStreamSubscription = _collaborationService.musicStream.listen((musics) {
      setState(() {
        _teamPlaylistMusicsFuture = Future.value(musics);
      });
    });
  }

  Future<void> _initializeServices() async {
    try {
      accessToken = await _tokenStorage.getAccessToken();
      print('Initial Access Token: $accessToken');
      if (accessToken == null || accessToken!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
        }
        return;
      }

      if (accessToken != null) {
        _teamPlaylistApiService = TeamPlaylistApiService(accessToken: accessToken);
        _collaborationService = TeamPlaylistCollaborationService(accessToken: accessToken!);
        await _refreshPlaylists();
      }
      // if (_playlists.isNotEmpty) {
      //   setState(() {
      //     _selectedPlaylistId = _playlists.first.playlistId;
      //     _loadPlaylistMusics();
      //   });
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('토큰을 가져오는데 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _musicStreamSubscription?.cancel();
    _collaborationService.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    if (_isLoading || accessToken == null) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final playlistList = await _playlistService.getPlaylistPreViewList(accessToken!);
      setState(() {
        _playlists = playlistList.playlistPreviewList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadTeamPlaylists() async {
    if (_isLoading || accessToken == null) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final teamPlaylistList = await _teamPlaylistApiService.getTeamPlaylistPreViewList();
      setState(() {
        _teamPlaylists = teamPlaylistList.teamPlaylistPreviewList;
        _isLoading = false;
        // if (_selectedType == PlaylistType.team && _teamPlaylists.isNotEmpty) {
        //   _selectedPlaylistId = _teamPlaylists.first.teamPlaylistId;
        //   _loadTeamPlaylistMusics();
        // }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀 플레이리스트를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedMusics() async {
    if (_selectedPlaylistId == null || _selectedMusicIds.isEmpty) return;

    try {
      await _playlistService.deletePlaylistMusics(accessToken!, _selectedPlaylistId!, _selectedMusicIds.toList());
      setState(() {
        _selectedMusicIds.clear();
        _isEditMode = false;
        _loadPlaylistMusics();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 곡들이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('곡 삭제에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedTeamMusics() async {
    if (_selectedPlaylistId == null || _selectedMusicIds.isEmpty) return;

    try {
      await _collaborationService.deleteTeamPlaylistMusics(
          _selectedPlaylistId!,
          _selectedMusicIds.toList()
      );

      setState(() {
        _selectedMusicIds.clear();
        _isEditMode = false;
        _loadPlaylistMusics();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 곡들이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('곡 삭제에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _handleReorder(List<PlaylistMusicDto> musicList, int oldIndex, int newIndex) async {
    HapticFeedback.mediumImpact();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final List<PlaylistMusicDto> originalList = List.from(musicList);

    try {
      setState(() {
        final item = musicList.removeAt(oldIndex);
        musicList.insert(newIndex, item);
      });

      final List<Map<String, dynamic>> updateMusic = musicList.asMap().entries.map((entry) {
        return {
          'playlistMusicId': entry.value.playlistMusicMappingId,
          'musicOrder': entry.key + 1
        };
      }).toList();

      await _playlistService.updatePlaylistOrder(
          accessToken!,
          _selectedPlaylistId!,
          updateMusic
      );

      await _refreshPlaylists();
    } catch (e) {
      print('Error during reorder: $e');
      setState(() {
        musicList.clear();
        musicList.addAll(originalList);
        _loadPlaylistMusics();
      });
      await _refreshPlaylists();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('순서 변경에 실패했습니다: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleTeamReorder(List<TeamPlaylistMusicDto> musicList, int oldIndex, int newIndex) async {
    HapticFeedback.mediumImpact();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final List<TeamPlaylistMusicDto> originalList = List.from(musicList);

    try {
      setState(() {
        final item = musicList.removeAt(oldIndex);
        musicList.insert(newIndex, item);
      });

      final List<Map<String, dynamic>> updateMusic = musicList.asMap().entries.map((entry) {
        return {
          'teamPlaylistMusicId': entry.value.teamPlaylistMusicMappingId,
          'musicOrder': entry.key + 1
        };
      }).toList();

      await _collaborationService.updateTeamPlaylistOrder(
          _selectedPlaylistId!,
          updateMusic
      );

      await _refreshPlaylists();
    } catch (e) {
      print('Error during reorder: $e');
      setState(() {
        musicList.clear();
        musicList.addAll(originalList);
        _loadPlaylistMusics();
      });
      await _refreshPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('순서 변경에 실패했습니다: ${e.toString()}')),
        );
      }
    }

  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      body: _buildBody(),
      currentIndex: _currentIndex,
      onTabTapped: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildPlaylistDropdown(),
        Expanded(
          child: _selectedPlaylistId == null
              ? const Center(
            child: Text(
              '플레이리스트를 선택해주세요',
              style: TextStyle(fontSize: 16),
            ),
          )
              : _buildSelectedPlaylistContent(),
        ),
      ],
    );
  }

  Widget _buildSelectedPlaylistContent() {
    if (_selectedPlaylistId == null) {
      return const Center(child: Text('플레이리스트를 선택해주세요'));
    }

    if (_selectedType == PlaylistType.personal) {
      _loadPlaylistMusics();
    } else {
      _loadTeamPlaylistMusics();
    }

    return FutureBuilder<dynamic>(
      future: _selectedType == PlaylistType.personal
          ? _playlistMusicsFuture
          : _teamPlaylistMusicsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error loading playlist: ${snapshot.error}');
          if (snapshot.error.toString().contains('403')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('인증이 만료되었습니다. 다시 로그인해주세요'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await _tokenStorage.deleteAccessToken();
                    },
                    child: const Text('다시 로그인'),
                  )
                ],
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('플레이리스트를 불러오는데 실패했습니다'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        final musicList = snapshot.data ?? [];

        // if (musicList.isEmpty) {
        //   return Center(
        //     child: Column(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         Text(
        //           '${getPlaylistName()}이(가) 비어있습니다',
        //           style: const TextStyle(fontSize: 16),
        //         ),
        //         const SizedBox(height: 16),
        //         ElevatedButton(
        //           onPressed: () {
        //             ScaffoldMessenger.of(context).showSnackBar(
        //               const SnackBar(content: Text('음악 추가 기능은 준비중입니다')),
        //             );
        //           },
        //           child: const Text('음악 추가하기'),
        //         ),
        //       ],
        //     ),
        //   );
        // }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            getPlaylistName(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isEditMode)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _showDeletePlaylistConfirmDialog(context),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          if(_selectedType == PlaylistType.team && !_isEditMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: () async
                                {
                                  if (_selectedPlaylistId != null) {  // null 체크
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TeamManagementPage(
                                          teamPlaylistId: _selectedPlaylistId!,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      _loadTeamPlaylists();
                                      setState(() {
                                        _selectedPlaylistId = null;
                                      });
                                    }

                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('플레이리스트를 선택해주세요')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.group),
                                label: const Text('팀원 관리'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.brown[300],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          if (_isEditMode)
                            TextButton(
                              onPressed: _selectedType == PlaylistType.personal
                                  ? _deleteSelectedMusics
                                  : _deleteSelectedTeamMusics,
                              child: const Text('삭제', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${musicList.length}곡',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditMode = !_isEditMode;
                            if (!_isEditMode) {
                              _selectedMusicIds.clear();
                            }
                          });
                        },
                        child: Text(_isEditMode ? '완료' : '편집'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isEditMode
                  ? ReorderableListView.builder(
                itemCount: musicList.length,
                onReorder: (oldIndex, newIndex) =>
                _selectedType == PlaylistType.personal
                    ? _handleReorder(musicList, oldIndex, newIndex)
                    : _handleTeamReorder(musicList, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final music = musicList[index];
                  return ListTile(
                    key: Key('${_selectedType.toString()}-${music.musicId}'),
                    leading: Checkbox(
                      value: _selectedMusicIds.contains(music.musicId),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedMusicIds.add(music.musicId);
                          } else {
                            _selectedMusicIds.remove(music.musicId);
                          }
                        });
                      },
                    ),
                    title: Text(music.title),
                    subtitle: Text(music.artist),
                    trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                  );
                },
              )
                  : ListView.builder(
                itemCount: musicList.length,
                itemBuilder: (context, index) {
                  final music = musicList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(music.thumbnail),
                      backgroundColor: Colors.brown.shade200,
                    ),
                    title: Text(music.title),
                    subtitle: Text(music.artist),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => YoutubePlayerScreen(
                              youtubeUrl: music.url,
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
        );
      },
    );
  }

  Widget _buildPlaylistDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF6C48A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // 플레이리스트 타입 선택 드롭다운
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: DropdownButton<PlaylistType>(
                    value: _selectedType,  // null 허용
                    hint: const Text('플레이리스트 타입 선택'),  // 추가
                    icon: const Icon(Icons.arrow_drop_down),
                    iconSize: 24,
                    elevation: 16,
                    style: const TextStyle(color: Colors.black),
                    underline: Container(
                      height: 2,
                      color: Colors.brown,
                    ),
                    onChanged: (PlaylistType? newValue) {
                      if (newValue != null) {
                        _onPlaylistTypeChanged(newValue);
                      }
                    },
                    items: const[
                      DropdownMenuItem(
                        value: PlaylistType.personal,
                        child: Text('개인 플레이리스트'),
                      ),
                      DropdownMenuItem(
                        value: PlaylistType.team,
                        child: Text('팀 플레이리스트'),
                      ),
                    ],
                  ),
                ),
                // 플레이리스트 선택 드롭다운
                Expanded(
                  child: DropdownButton<int?>(
                    value: _selectedPlaylistId,
                    icon: const Icon(Icons.arrow_drop_down),
                    iconSize: 24,
                    elevation: 16,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.black),
                    underline: Container(
                      height: 2,
                      color: Colors.brown,
                    ),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedPlaylistId = newValue;
                        _isEditMode = false;
                        _selectedMusicIds.clear();
                        if (newValue != null) {
                          _loadPlaylistMusics();
                        }
                      });
                    },
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(_selectedType == PlaylistType.personal
                            ? '선택'
                            : '선택'),
                      ),
                      ..._selectedType == PlaylistType.personal
                          ? _playlists.map((playlist) => DropdownMenuItem<int?>(
                        value: playlist.playlistId,
                        child: Text(playlist.name),
                      ))
                          : _teamPlaylists.map((teamPlaylist) => DropdownMenuItem<int?>(
                        value: teamPlaylist.teamPlaylistId,
                        child: Text(teamPlaylist.name),
                      )), // 팀 플레이리스트일 경우 빈 리스트 (추후 팀 플레이리스트 목록으로 대체)
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          ElevatedButton(
            onPressed: () {
              if (_selectedType == PlaylistType.personal) {
                _showCreatePlaylistDialog(context);
              } else {
                _showCreateTeamPlaylistDialog(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('새 플레이리스트'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "플레이리스트 이름을 입력하세요"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('생성'),
              onPressed: () async {  // async 추가
                if (controller.text.isNotEmpty) {
                  Navigator.of(context).pop();  // 다이얼로그를 먼저 닫음
                  await _createPlaylist(context, controller.text);  // await 추가
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateTeamPlaylistDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('새 팀 플레이리스트'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "플레이리스트 이름을 입력하세요"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('생성'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _createTeamPlaylist(context, controller.text);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeletePlaylistConfirmDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('플레이리스트 삭제'),
          content: Text('${getPlaylistName()}을(를) 정말 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deletePlaylist();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context, String playlistName) async {
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      // await를 추가하여 생성이 완료될 때까지 대기
      print(accessToken);
      print(playlistName);
      final playlist = await _playlistService.createPlaylist(accessToken!, playlistName);
      print(playlist);

      // 성공 메시지를 먼저 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 "$playlistName"가 생성되었습니다')),
        );
      }

      // 새로고침을 별도로 처리
      if (mounted) {
        setState(() {
          // 새로 생성된 플레이리스트를 목록 맨 앞에 추가
          _playlists.insert(0, playlist);
          // 새로 생성된 플레이리스트를 선택
          _selectedPlaylistId = playlist.playlistId;
          // 음악 목록 로드
          _loadPlaylistMusics();
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 생성 실패: $e')),
        );
      }
    }
  }

  Future<void> _createTeamPlaylist(BuildContext context, String playlistName) async {
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      final teamPlaylist = await _teamPlaylistApiService.createTeamPlaylist(playlistName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 "$playlistName"가 생성되었습니다')),
        );
        await _refreshPlaylists();
      }
      // 새로고침을 별도로 처리
      if (mounted) {
        setState(() {
          // 새로 생성된 플레이리스트를 목록 맨 앞에 추가
          _teamPlaylists.insert(0, teamPlaylist);
          // 새로 생성된 플레이리스트를 선택
          _selectedPlaylistId = teamPlaylist.teamPlaylistId;
          // 음악 목록 로드
          _loadPlaylistMusics();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀 플레이리스트 생성 실패: $e')),
        );
      }
    }
  }

  Future<void> _deletePlaylist() async {
    if (_selectedPlaylistId == null) return;

    try {
      if (_selectedType == PlaylistType.personal) {
        await _playlistService.deletePlaylist(accessToken!, _selectedPlaylistId!);
      } else {
        await _teamPlaylistApiService.deleteTeamPlaylist(_selectedPlaylistId!);
      }

      setState(() {
        if (_selectedType == PlaylistType.personal) {
          _playlists.removeWhere((p) => p.playlistId == _selectedPlaylistId);
        } else {
          _teamPlaylists.removeWhere((p) => p.teamPlaylistId == _selectedPlaylistId);
        }
        _selectedPlaylistId = null;
        _isEditMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('플레이리스트가 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 삭제에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _refreshPlaylists() async {
    if (accessToken == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedType == PlaylistType.personal) {
        final playlistList = await _playlistService.getPlaylistPreViewList(accessToken!);
        setState(() {
          _playlists = playlistList.playlistPreviewList;
          _isLoading = false;
        });
      } else {
        final teamPlaylistList = await _teamPlaylistApiService.getTeamPlaylistPreViewList();
        setState(() {
          _teamPlaylists = teamPlaylistList.teamPlaylistPreviewList;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }
  void _onPlaylistTypeChanged(PlaylistType newType) {
    setState(() {
      _selectedType = newType;
      _isEditMode = false;
      _selectedMusicIds.clear();
      _selectedPlaylistId = null;

      if (newType == PlaylistType.personal) {
        _collaborationService.disconnect(); // 개인 플레이리스트로 전환시 웹소켓 연결 해제
        _loadPlaylists();
      } else {
        _loadTeamPlaylists();
      }
    });
  }
}

