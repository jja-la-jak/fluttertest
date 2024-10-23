import 'package:http/http.dart' as http;
import 'dart:convert';
import '../modules/playlist_models.dart';

class PlaylistService {
  static const String baseUrl = 'https://gnumusic.shop/api';

  Future<PlaylistPreViewDto> createPlaylist(String accessToken, String playlistName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/playlists'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'name': playlistName,
      }),
    );

    if (response.statusCode == 201) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        return PlaylistPreViewDto.fromJson(jsonResponse['result']);
      } else {
        throw Exception('${jsonResponse['code']}: ${jsonResponse['message']}');
      }
    } else {
      throw Exception('Failed to create playlist: ${response.statusCode}');
    }
  }

  Future<PlaylistPreViewListDto> getPlaylistPreViewList(String accessToken, int page) async {
    final response = await http.get(
      Uri.parse('$baseUrl/playlists'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        return PlaylistPreViewListDto.fromJson(jsonResponse['result']);
      } else {
        throw Exception('${jsonResponse['code']}: ${jsonResponse['message']}');
      }
    } else {
      throw Exception('Failed to load playlists');
    }
  }

  Future<List<PlaylistMusicDto>> getPlaylistMusics(String accessToken, int playlistId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/playlists/$playlistId/musics'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        if (jsonResponse['isSuccess']) {
          final musicList = jsonResponse['result']['musicList'] as List;
          return musicList.map((music) => PlaylistMusicDto.fromJson(music)).toList();
        } else {
          switch(jsonResponse['code']) {
            case 'PLAYLIST4001':
              throw Exception('플레이리스트를 찾을 수 없습니다.');
            case 'AUTH4001':
            case 'AUTH4002':
              throw Exception('로그인이 필요합니다.');
            case 'AUTH4003':
              throw Exception('접근 권한이 없습니다.');
            default:
              throw Exception('${jsonResponse['code']}: ${jsonResponse['message']}');
          }
        }
      } else {
        throw Exception('Failed to load playlist musics: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getPlaylistMusics: $e');
      rethrow;
    }
  }
}