import 'package:flutter/material.dart';
import '../modules/custom_scaffold.dart';
import '../modules/playlist_models.dart';
import '../service/playlist_service.dart';
import '../services/token_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'full_playlist_page.dart';
import 'package:flutter_project/screens/youtube_player_screen.dart';
import 'package:flutter_project/service/music_service.dart';
import 'package:flutter/services.dart' show HapticFeedback;

enum PlaylistType {personal, team}
PlaylistType _selectedType = PlaylistType.personal;
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  int _currentIndex = 0;
  int? _selectedPlaylistId;
  List<PlaylistPreViewDto> _playlists = [];
  String? accessToken;
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isEditMode = false;
  Set<int> _selectedMusicIds = {};
  final TokenStorage _tokenStorage = TokenStorage();
  final PlaylistService _playlistService = PlaylistService();
  late Future<List<PlaylistMusicDto>> _playlistMusicsFuture;

  @override
  void initState() {
    super.initState();
    _initializeToken();
  }

  void _loadPlaylistMusics() {
    if (_selectedPlaylistId != null && accessToken != null) {
      _playlistMusicsFuture = _playlistService.getPlaylistMusics(
          accessToken!,
          _selectedPlaylistId!
      );
    }
  }

  Future<void> _initializeToken() async {
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
      await _refreshPlaylists();
      if (_playlists.isNotEmpty) {
        setState(() {
          _selectedPlaylistId = _playlists.first.playlistId;
          _loadPlaylistMusics();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('토큰을 가져오는데 실패했습니다: $e')),
        );
      }
    }
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
        _currentPage++;
        _isLoading = false;
        if (_selectedType == PlaylistType.personal && _playlists.isNotEmpty) {
          _selectedPlaylistId = _playlists.first.playlistId;
          _loadPlaylistMusics();
        }
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

    _loadPlaylistMusics();

    final selectedPlaylist = _playlists.firstWhere(
          (p) => p.playlistId == _selectedPlaylistId,
      orElse: () => _playlists.first,
    );

    return FutureBuilder<List<PlaylistMusicDto>>(
      future: _playlistMusicsFuture,
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

        if (musicList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${selectedPlaylist.name}이(가) 비어있습니다',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('음악 추가 기능은 준비중입니다')),
                    );
                  },
                  child: const Text('음악 추가하기'),
                ),
              ],
            ),
          );
        }

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
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              selectedPlaylist.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isEditMode) ...[
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.black54),
                                onPressed: () => _showEditTitleDialog(selectedPlaylist),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _showDeletePlaylistDialog(selectedPlaylist),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isEditMode)
                        TextButton(
                          onPressed: _deleteSelectedMusics,
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
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
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Material(
                        elevation: 5 * animation.value,
                        color: Colors.white,
                        shadowColor: Colors.blue.withOpacity(0.3),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) =>
                    _handleReorder(musicList, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final music = musicList[index];
                  return ListTile(
                    key: ValueKey(music.musicId),
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
                      backgroundColor: Colors.brown.shade200,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(music.title),
                    subtitle: Text(music.artist),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => YoutubePlayerScreen(youtubeUrl: music.url),
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
                    value: _selectedType,
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
                        setState(() {
                          _selectedType = newValue;
                          _isEditMode = false;
                          _selectedMusicIds.clear();
                          if (newValue == PlaylistType.personal && _playlists.isNotEmpty) {
                            _selectedPlaylistId = _playlists.first.playlistId;
                            _loadPlaylistMusics();
                          } else {
                            _selectedPlaylistId = null;
                          }
                        });
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
                            ? '나의 플레이리스트'
                            : '팀 플레이리스트'),
                      ),
                      ..._selectedType == PlaylistType.personal
                          ? _playlists.map((playlist) => DropdownMenuItem<int?>(
                        value: playlist.playlistId,
                        child: Text(playlist.name),
                      ))
                          : [], // 팀 플레이리스트일 경우 빈 리스트 (추후 팀 플레이리스트 목록으로 대체)
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
            child: const Text('생성'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
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


  Future<void> _createPlaylist(BuildContext context, String playlistName) async {
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      // await를 추가하여 생성이 완료될 때까지 대기
      final playlist = await _playlistService.createPlaylist(accessToken!, playlistName);

      // 성공 메시지를 먼저 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 "${playlistName}"가 생성되었습니다')),
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

  Future<void> _showDeletePlaylistDialog(PlaylistPreViewDto playlist) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('플레이리스트 삭제'),
          content: Text('${playlist.name}와 모든 음악이 삭제됩니다.\n계속하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePlaylist(playlist.playlistId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePlaylist(int playlistId) async {
    try {
      await _playlistService.deletePlaylist(accessToken!, playlistId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('플레이리스트가 삭제되었습니다')),
        );
        setState(() {
          _playlists.removeWhere((p) => p.playlistId == playlistId);
          _selectedPlaylistId = null;
          _isEditMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 삭제 실패: $e')),
        );
      }
    }
  }
  Future<void> _showEditTitleDialog(PlaylistPreViewDto playlist) async {
    final TextEditingController controller = TextEditingController(text: playlist.name);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('플레이리스트 이름 수정'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "새로운 이름을 입력하세요",
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('저장'),
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  try {
                    await _playlistService.updatePlaylistTitle(
                        accessToken!,
                        playlist.playlistId,
                        controller.text
                    );
                    setState(() {
                      // UI 업데이트
                      final index = _playlists.indexWhere((p) => p.playlistId == playlist.playlistId);
                      if (index != -1) {
                        _playlists[index] = PlaylistPreViewDto(
                          playlistId: playlist.playlistId,
                          name: controller.text,
                          createdDate: _playlists[index].createdDate,
                        );
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('플레이리스트 이름이 수정되었습니다')),
                    );
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('플레이리스트 이름 수정 실패: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
// 팀 플레이리스트 생성 다이얼로그
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

// 팀 플레이리스트 생성 메서드 (API 연동 필요)
  Future<void> _createTeamPlaylist(BuildContext context, String playlistName) async {
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    try {
      // TODO: 팀 플레이리스트 생성 API 호출
      // final playlist = await _playlistService.createTeamPlaylist(accessToken!, playlistName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('팀 플레이리스트 생성 기능은 준비중입니다.')),
        );
        await _refreshPlaylists();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀 플레이리스트 생성 실패: $e')),
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
      final playlistList = await _playlistService.getPlaylistPreViewList(accessToken!);
      setState(() {
        _playlists = playlistList.playlistPreviewList;
        _isLoading = false;

        // 개인 플레이리스트이고 플레이리스트가 있을 경우 첫 번째 항목 자동 선택
        if (_selectedType == PlaylistType.personal && _playlists.isNotEmpty) {
          _selectedPlaylistId = _playlists.first.playlistId;
          _loadPlaylistMusics();
        }
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
}

