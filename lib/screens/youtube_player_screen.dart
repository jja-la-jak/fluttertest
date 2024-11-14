import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../service/music_service.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final String youtubeUrl;

  const YoutubePlayerScreen({Key? key, required this.youtubeUrl}) : super(key: key);

  @override
  _YoutubePlayerScreenState createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController _controller;
  late int _musicId;

  @override
  void initState() {
    super.initState();
    _setupYoutubePlayer();
    _increaseViewCount();
    _getMusicId();
  }
  void _setupYoutubePlayer() {
    _controller = YoutubePlayerController(
      initialVideoId: YoutubePlayer.convertUrlToId(widget.youtubeUrl)!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }


  Future<void> _getMusicId() async {
    _musicId = await MusicService.getMusicIdFromUrl(widget.youtubeUrl);
  }

  Future<void> _increaseViewCount() async {
    if (_musicId != null) {
      try {
        final updatedMusic = await MusicService.increaseViewCount(_musicId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('조회수가 증가했습니다: ${updatedMusic.viewCount}'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('조회수 증가 에러: $e'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('음악 ID를 찾을 수 없습니다'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Player'),
      ),
      body: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller,
        ),
        builder: (context, player) => Column(
          children: [
            player,
          ],
        ),
      ),
    );
  }
}