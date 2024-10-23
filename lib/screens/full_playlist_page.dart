import 'package:flutter/material.dart';
import '../modules/playlist_models.dart';
import '../service/playlist_service.dart';
import 'youtube_player_screen.dart';

class FullPlaylistPage extends StatefulWidget {
  final PlaylistPreViewDto playlist;
  final String accessToken;

  const FullPlaylistPage({
    Key? key,
    required this.playlist,
    required this.accessToken,
  }) : super(key: key);

  @override
  _FullPlaylistPageState createState() => _FullPlaylistPageState();
}

class _FullPlaylistPageState extends State<FullPlaylistPage> {
  final PlaylistService _playlistService = PlaylistService();
  List<PlaylistMusicDto> _musicList = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylistMusics();
  }

  Future<void> _loadPlaylistMusics() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final musics = await _playlistService.getPlaylistMusics(
        widget.accessToken,
        widget.playlist.playlistId,
      );

      if (mounted) {
        setState(() {
          _musicList = musics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('오류가 발생했습니다: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlaylistMusics,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_musicList.isEmpty) {
      return Center(
        child: Column(
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
        ),
      );
    }

    return ListView.builder(
      itemCount: _musicList.length,
      itemBuilder: (context, index) {
        final music = _musicList[index];
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
  }
}