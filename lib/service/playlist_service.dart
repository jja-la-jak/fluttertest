import 'package:http/http.dart' as http;
import 'dart:convert';
import '../modules/playlist_models.dart';
import '../services/token_storage.dart';

class PlaylistService {
  static const String baseUrl = 'https://gnumusic.shop/api';
  final TokenStorage _tokenStorage = TokenStorage();

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
      Uri.parse('$baseUrl/playlists/$playlistId/musics'),
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
      await _tokenStorage.deleteAccessToken();
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
}