import 'package:http/http.dart' as http;
import 'dart:convert';
import '../modules/playlist_models.dart';
import '../services/token_storage.dart';

class PlaylistService {
  static const String baseUrl = 'https://gnumusic.shop/api';
  final TokenStorage _tokenStorage = TokenStorage();
  String? accessToken;
  PlaylistService({this.accessToken});
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

  Future<PlaylistPreViewListDto> getPlaylistPreViewList(String accessToken) async {
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
    final response = await http.get(
      Uri.parse('$baseUrl/playlists/$playlistId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        final List musics = jsonResponse['result']['playlistMusicList'] as List;
        return musics.map((music) => PlaylistMusicDto.fromJson(music)).toList();
      } else {
        throw Exception('API error: ${jsonResponse['message']}');
      }
    } else if (response.statusCode == 403) {
      throw Exception('Access token expired. Please log in again.');
    } else {
      throw Exception('HTTP error: ${response.statusCode}');
    }
  }

  Future<void> _refreshAccessToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'RefreshToken': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['isSuccess']) {
          final newAccessToken = jsonResponse['result']['accessToken'];
          final newAccessTokenExpiresAt = DateTime.now().add(const Duration(hours: 1));
          await _tokenStorage.saveAccessToken(newAccessToken, newAccessTokenExpiresAt);
        }
      }
    }
  }
  Future<void> deletePlaylistMusics(int playlistId, List<int> musicIds) async {
    final url = Uri.parse('https://your-api-url.com/api/playlists/$playlistId/musics');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({'musicIds': musicIds});

    try {
      final response = await http.delete(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete musics: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);
      if (!jsonResponse['isSuccess']) {
        switch(jsonResponse['code']) {
          case 'PLAYLIST4001':
            throw Exception('플레이리스트를 찾을 수 없습니다');
          case 'PLAYLIST_MUSIC_MAPPING4004':
            throw Exception('플레이리스트에서 해당 음악을 찾을 수 없습니다');
          case 'AUTH4001':
          case 'AUTH4002':
            throw Exception('인증이 만료되었습니다. 다시 로그인해주세요');
          case 'AUTH4003':
            throw Exception('접근 권한이 없습니다');
          default:
            throw Exception(jsonResponse['message'] ?? '알 수 없는 오류가 발생했습니다');
        }
      }
    } catch (e) {
      throw Exception('음악 삭제 중 오류가 발생했습니다: $e');
    }
  }
}