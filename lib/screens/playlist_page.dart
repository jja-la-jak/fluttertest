import 'package:flutter/material.dart';
import '../modules/custom_scaffold.dart';
import '../modules/playlist_models.dart';
import '../service/playlist_service.dart';
import '../services/token_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'full_playlist_page.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  int _currentIndex = 0;
  String _selectedPlaylist = '나의 플레이리스트';
  List<PlaylistPreViewDto> _playlists = [];
  String? accessToken;
  int _currentPage = 0;
  bool _isLoading = false;
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
      if (accessToken == null) {
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
      final playlistList = await _playlistService.getPlaylistPreViewList(accessToken!, _currentPage);
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
          child: _selectedPlaylist == '나의 플레이리스트'
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
    final selectedPlaylist = _playlists.firstWhere((p) => p.name == _selectedPlaylist);

    return FutureBuilder<List<PlaylistMusicDto>>(
      future: _playlistService.getPlaylistMusics(accessToken!, selectedPlaylist.playlistId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('플레이리스트를 불러오는데 실패했습니다'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // 강제 리빌드로 다시 시도
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        final musicList = snapshot.data ?? [];

        if (musicList.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '플레이리스트가 비어있습니다',
                style: TextStyle(fontSize: 16),
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
          );
        }

        return ListView.builder(
          itemCount: musicList.length,
          itemBuilder: (context, index) {
            final music = musicList[index];
            return ListTile(
              title: Text(music.title),
              subtitle: Text(music.artist),
              trailing: Text('조회수: ${music.viewCount}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => YoutubePlayerScreen(youtubeUrl: music.url),
                  ),
                );
              },
            );
          },
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
          DropdownButton<String>(
            value: _selectedPlaylist,
            icon: const Icon(Icons.arrow_drop_down),
            iconSize: 24,
            elevation: 16,
            style: const TextStyle(color: Colors.black),
            underline: Container(
              height: 2,
              color: Colors.brown,
            ),
            onChanged: (String? newValue) {
              setState(() {
                _selectedPlaylist = newValue!;
              });
            },
            items: ['나의 플레이리스트', ..._playlists.map((p) => p.name)]
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          Row(
            children: [
              if (_selectedPlaylist != '나의 플레이리스트')
                TextButton(
                  onPressed: () {
                    final selectedPlaylist = _playlists.firstWhere((p) => p.name == _selectedPlaylist);
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

class YoutubePlayerScreen extends StatefulWidget {
  final String youtubeUrl;

  const YoutubePlayerScreen({
    Key? key,
    required this.youtubeUrl
  }) : super(key: key);

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl);
    print(videoId);
    _controller = YoutubePlayerController(
      initialVideoId: videoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Player'),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}