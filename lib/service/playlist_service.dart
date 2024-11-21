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
  Future<void> deletePlaylistMusics(String accessToken,int playlistId, List<int> musicIds) async {
    print('playlistId : $playlistId');
    print('musiclist : $musicIds');
    final url = Uri.parse('https://gnumusic.shop/api/playlists/$playlistId/musics');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({'musicIds': musicIds});
    print('url : $url, headers : $headers, body : $body');
    try {
      final response = await http.delete(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete musics: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);
      print('jsonResponse : $jsonResponse');
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
  Future<void> deletePlaylist(String accessToken, int playlistId) async {
    try {
      final response = await _makeRequest(
        Uri.parse('$baseUrl/playlists/$playlistId'),
        accessToken,
        method: 'DELETE',
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete playlist');
      }

      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (!jsonResponse['isSuccess']) {
        throw Exception(jsonResponse['message']);
      }
    } catch (e) {
      print('Error in deletePlaylist: $e');
      rethrow;
    }
  }

  Future<http.Response> _makeRequest(Uri uri, String accessToken, {String method = 'GET'}) async {
    try {
      late http.Response response;

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
      // 다른 HTTP 메서드도 필요한 경우 여기에 추가
      }

      if (response.statusCode == 403) {
        final newToken = await TokenStorage().getRefreshToken();
        if (newToken != null) {
          headers['Authorization'] = 'Bearer $newToken';
          switch (method) {
            case 'GET':
              response = await http.get(uri, headers: headers);
              break;
            case 'DELETE':
              response = await http.delete(uri, headers: headers);
              break;
          }
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePlaylistTitle(String accessToken, int playlistId, String newTitle) async {
    final url = Uri.parse(
        'https://gnumusic.shop/api/playlists/$playlistId/title');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'name': newTitle});

    try {
      final response = await http.patch(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['isSuccess']) {
          print('Successfully updated playlist title');
        } else {
          switch (jsonResponse['code']) {
            case 'PLAYLIST4001':
              throw Exception('플레이리스트를 찾을 수 없습니다');
            case 'AUTH4001':
            case 'AUTH4002':
              throw Exception('토큰이 만료되었습니다');
            case 'AUTH4003':
              throw Exception('접근 권한이 없습니다');
            case 'COMMON4000':
              throw Exception('잘못된 입력입니다');
            default:
              throw Exception(jsonResponse['message']);
          }
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> updatePlaylistOrder(String accessToken, int playlistId, List<Map<String, dynamic>> updateMusic) async {
    final url = Uri.parse('https://gnumusic.shop/api/playlists/$playlistId/order');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({'updateMusic': updateMusic});
    print('Request URL: $url');
    print('Request Headers: $headers');
    print('Request Body: $body');

    try {
      final response = await http.patch(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['isSuccess']) {
          print('Successfully updated playlist order');
        } else {
          switch(jsonResponse['code']) {
            case 'PLAYLIST4001':
              throw Exception('플레이리스트를 찾을 수 없습니다');
            case 'PLAYLIST_MUSIC_MAPPING4004':
              throw Exception('플레이리스트에서 음악을 찾을 수 없습니다');
            case 'PLAYLIST_MUSIC_MAPPING4005':
              throw Exception('중복된 음악이 있습니다');
            case 'PLAYLIST_MUSIC_MAPPING4006':
              throw Exception('중복된 순서가 있습니다');
            case 'PLAYLIST_MUSIC_MAPPING4008':
              throw Exception('유효하지 않은 음악 순서입니다');
            case 'AUTH4001':
            case 'AUTH4002':
              throw Exception('인증이 만료되었습니다. 다시 로그인해주세요');
            case 'AUTH4003':
              throw Exception('접근 권한이 없습니다');
            default:
              throw Exception(jsonResponse['message'] ?? '알 수 없는 오류가 발생했습니다');
          }
        }
      } else {
        throw Exception('Failed to update playlist order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updatePlaylistOrder: $e');
      rethrow;
    }
  }
}
