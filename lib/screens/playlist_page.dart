import 'package:flutter/material.dart';
import '../modules/custom_scaffold.dart';
import '../modules/playlist_models.dart';
import '../service/playlist_service.dart';
import '../services/token_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'full_playlist_page.dart';
import 'package:flutter_project/screens/youtube_player_screen.dart';
import 'package:flutter_project/service/music_service.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeToken();
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
      _loadPlaylists();
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
        _playlists.addAll(playlistList.playlistPreviewList);
        _currentPage++;
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

  Future<void> _deleteSelectedMusics() async {
    if (_selectedPlaylistId == null || _selectedMusicIds.isEmpty) return;

    try {
      await _playlistService.deletePlaylistMusics(_selectedPlaylistId!, _selectedMusicIds.toList());
      setState(() {
        _selectedMusicIds.clear();
        _isEditMode = false;
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

    print('Selected Playlist ID: $_selectedPlaylistId');
    final selectedPlaylist = _playlists.firstWhere(
          (p) => p.playlistId == _selectedPlaylistId,
      orElse: () => _playlists.first,
    );
    print('Selected Playlist Name: ${selectedPlaylist.name}');

    return FutureBuilder<List<PlaylistMusicDto>>(
      future: _playlistService.getPlaylistMusics(accessToken!, selectedPlaylist.playlistId),
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
                  const SizedBox(height:8),
                  ElevatedButton(onPressed: () async{
                    await _tokenStorage.deleteAccessToken();
                  },
                    child: const Text('다시로그인)'),
                  )
                ]
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
        print('Loaded ${musicList.length} songs');

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

        // 음악 목록 표시
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
                      Text(
                        selectedPlaylist.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
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
              child: ListView.builder(
                itemCount: musicList.length,
                itemBuilder: (context, index) {
                  final music = musicList[index];
                  return ListTile(
                    leading: _isEditMode
                        ? Checkbox(
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
                    )
                        : CircleAvatar(
                      backgroundColor: Colors.brown.shade200,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(music.title),
                    subtitle: Text(music.artist),
                    trailing: _isEditMode
                        ? null
                        : IconButton(
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
          DropdownButton<int?>(
            value: _selectedPlaylistId,
            icon: const Icon(Icons.arrow_drop_down),
            iconSize: 24,
            elevation: 16,
            style: const TextStyle(color: Colors.black),
            underline: Container(
              height: 2,
              color: Colors.brown,
            ),
            onChanged: (int? newValue) {
              setState(() {
                _selectedPlaylistId = newValue;
                print('Changed playlist ID to: $newValue'); // 변경된 ID 출력
              });
            },
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('나의 플레이리스트'),
              ),
              ..._playlists.map((playlist) => DropdownMenuItem<int?>(
                value: playlist.playlistId,
                child: Text(playlist.name),
              )),
            ],
          ),
          Row(
            children: [
              if (_selectedPlaylistId != null)
                TextButton(
                  onPressed: () {
                    final selectedPlaylist = _playlists.firstWhere(
                            (p) => p.playlistId == _selectedPlaylistId
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullPlaylistPage(
                          playlist: selectedPlaylist,
                          accessToken: accessToken!,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: const [
                      Text('더보기', style: TextStyle(color: Colors.black)),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _showCreatePlaylistDialog(context),
                child: const Text('생성'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
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
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _createPlaylist(context, controller.text);
                }
                Navigator.of(context).pop();
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
      final playlist = await _playlistService.createPlaylist(accessToken!, playlistName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이리스트 "${playlist.name}"가 생성되었습니다.')),
        );
        setState(() {
          _playlists.insert(0, playlist);
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
}

