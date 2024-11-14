import 'package:http/http.dart' as http;
import 'dart:convert';

class MusicService {
  static Future<int> getMusicIdFromUrl(String youtubeUrl) async {
    try {
      // 유튜브 URL에서 음악 ID 추출
      final Uri uri = Uri.parse(youtubeUrl);
      final queryParameters = uri.queryParameters;
      final musicId = queryParameters['v'];
      if (musicId != null) {
        return int.parse(musicId);
      } else {
        throw Exception('유효한 음악 ID를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('음악 ID 추출 에러: $e');
      rethrow;
    }
  }

  static Future<Music> increaseViewCount(int id) async {
    final response = await http.post(
      Uri.parse('https://gnumusic.shop/api/musics/$id/views'),
    );
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['isSuccess']) {
        return Music.fromJson(jsonResponse['result']);
      } else {
        throw Exception('API 에러: ${jsonResponse['message']}');
      }
    } else {
      throw Exception('HTTP 에러: ${response.statusCode}');
    }
  }
}

class Music {
  final int id;
  final String title;
  final String artist;
  final String url;
  final int viewCount;

  Music({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.viewCount,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      url: json['url'],
      viewCount: json['viewCount'],
    );
  }
}