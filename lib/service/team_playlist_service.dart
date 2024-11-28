import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../modules/team_playlist_models.dart';
import '../modules/lww_map.dart';
import '../config/environment.dart';
import 'package:uuid/uuid.dart';

class TeamPlaylistApiService {
  static String baseUrl = Environment.apiUrl;
  String? accessToken;

  TeamPlaylistApiService({this.accessToken});

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  void _handleError(String code, [String? message]) {
    switch(code) {
      case 'TEAM_PLAYLIST4001':
        throw Exception('플레이리스트를 찾을 수 없습니다');
      case 'TEAM_PLAYLIST_MUSIC_MAPPING4003':
        throw Exception('이미 추가된 음악입니다');
      case 'AUTH4001':
      case 'AUTH4002':
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요');
      case 'AUTH4003':
        throw Exception('접근 권한이 없습니다');
      default:
        throw Exception(message ?? '알 수 없는 오류가 발생했습니다');
    }
  }

  Future<TeamPlaylistPreViewDto> createTeamPlaylist(String playlistName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teamPlaylists'),
      headers: _headers,
      body: jsonEncode({
        'name': playlistName,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        return TeamPlaylistPreViewDto.fromJson(jsonResponse['result']);
      } else {
        throw Exception('${jsonResponse['code']}: ${jsonResponse['message']}');
      }
    } else {
      throw Exception('Failed to create playlist: ${response.statusCode}');
    }
  }

  Future<TeamPlaylistPreViewListDto> getTeamPlaylistPreViewList() async {
    final response = await http.get(
      Uri.parse('$baseUrl/teamPlaylists'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        var teamPlaylistPreViewListDto = TeamPlaylistPreViewListDto.fromJson(jsonResponse['result']);
        return teamPlaylistPreViewListDto;
      } else {
        throw Exception('${jsonResponse['code']}: ${jsonResponse['message']}');
      }
    } else {
      throw Exception('Failed to load playlists');
    }
  }

  Future<List<TeamPlaylistMusicDto>> getTeamPlaylistMusics(int playlistId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/teamPlaylists/$playlistId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      if (jsonResponse['isSuccess']) {
        final List musics = jsonResponse['result']['teamPlaylistMusicPreviewList'] as List;
        return musics.map((music) => TeamPlaylistMusicDto.fromJson(music)).toList();
      } else {
        throw Exception('API error: ${jsonResponse['message']}');
      }
    } else if (response.statusCode == 403) {
      throw Exception('Access token expired. Please log in again.');
    } else {
      throw Exception('HTTP error: ${response.statusCode}');
    }
  }

  Future<void> deleteTeamPlaylistMusics(int playlistId, List<int> musicIds) async {
    final url = Uri.parse('$baseUrl/teamPlaylists/$playlistId/musics');
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
        _handleError(jsonResponse['code']);
      }
    } catch (e) {
      print('Error deleting musics: $e');
      rethrow;
    }
  }

  Future<void> updateTeamPlaylistOrder(int playlistId, List<Map<String, dynamic>> updateMusic) async {
    final url = Uri.parse('$baseUrl/teamPlaylists/$playlistId/order');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'updateMusic': updateMusic});

    try {
      final response = await http.patch(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (!jsonResponse['isSuccess']) {
          _handleError(jsonResponse['code']);
        }
      } else {
        throw Exception('Failed to update playlist order: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateTeamPlaylistOrder: $e');
      rethrow;
    }
  }

  Future<void> addTeamPlaylistMusics(int playlistId, int musicId) async {
    final url = Uri.parse('$baseUrl/teamPlaylists/$playlistId/musics');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({'musicId': musicId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Exception('Failed to add musics: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);
      if (!jsonResponse['isSuccess']) {
        _handleError(jsonResponse['code']);
      }
    } catch (e) {
      print('Error adding musics: $e');
      rethrow;
    }
  }

  void setAccessToken(String s) {
    accessToken = s;
  }

  inviteMember(int i, String text) {}

  Future<List<TeamPlaylistMemberDto>> getTeamPlaylistMembers(int teamPlaylistId) async {
    final url = Uri.parse('$baseUrl/teamPlaylists/$teamPlaylistId/members');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

        if (jsonResponse['isSuccess']) {
          final memberMap = jsonResponse['result']['memberMap'] as Map<String, dynamic>;
          List<TeamPlaylistMemberDto> allMembers = [];

          // ADMIN 멤버 먼저 추가
          if (memberMap.containsKey('ADMIN')) {
            allMembers.addAll(
                (memberMap['ADMIN'] as List)
                    .map((member) => TeamPlaylistMemberDto.fromJson(member))
            );
          }

          // MEMBER 멤버 추가
          if (memberMap.containsKey('MEMBER')) {
            allMembers.addAll(
                (memberMap['MEMBER'] as List)
                    .map((member) => TeamPlaylistMemberDto.fromJson(member))
            );
          }

          return allMembers;
        } else {
          _handleError(jsonResponse['code'], jsonResponse['message']);
        }
      }

      throw Exception('Failed to load team members');
    } catch (e) {
      print('Error getting team members: $e');
      rethrow;
    }
  }

  inviteTeamPlaylistMember({required int teamId, required String email}) {}

  removeTeamPlaylistMember({required int teamPlaylistId, required int memberId}) {}

  updateTeamPlaylistMemberRole({required int teamPlaylistId, required int memberId, required bool isAdmin}) {}
}

class TeamPlaylistCollaborationService {
  static String wsUrl = Environment.wsUrl;
  final String? accessToken;
  final TeamPlaylistApiService _apiService;
  late LWWMap<TeamPlaylistMusicDto> _musicMap;
  StompClient? stompClient;
  final StreamController<List<TeamPlaylistMusicDto>> _musicStreamController = StreamController.broadcast();
  int? _currentPlaylistId;

  TeamPlaylistCollaborationService({required this.accessToken}) : _apiService = TeamPlaylistApiService(accessToken: accessToken){
    final peerId = 'peer-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4()}';
    _musicMap = LWWMap<TeamPlaylistMusicDto>(peerId, {});
  }

  void _notifyMusicListeners() {
    final musics = _musicMap.value.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.value!)
        .toList()
      ..sort((a, b) => a.musicOrder.compareTo(b.musicOrder));
    _musicStreamController.add(musics);
  }

  void _handleStompMessage(Map<String, dynamic> data) {
    if (data['type'] == 'state') {
      final Map<String, dynamic> remoteState = data['state'];

      // remoteState를 TeamPlaylistMusicDto로 변환하는 과정 추가
      final convertedState = remoteState.map((key, value) {
        final List<dynamic> stateList = value as List<dynamic>;
        if (stateList[2] != null && stateList[2] is Map<String, dynamic>) {
          // 세 번째 요소(value)를 TeamPlaylistMusicDto로 변환
          stateList[2] = TeamPlaylistMusicDto.fromJson(stateList[2] as Map<String, dynamic>);
        }
        return MapEntry(key, stateList);
      });

      _musicMap.merge(convertedState);
      _notifyMusicListeners();
    }
  }

  Future<void> _initializeStompClient(int playlistId) async {
    final completer = Completer<void>();

    stompClient = StompClient(
      config: StompConfig(
        url: '${Environment.wsUrl}/ws-stomp',
        onConnect: (frame) async{
          print('Connected to STOMP');

          try {
            final musics = await _apiService.getTeamPlaylistMusics(playlistId);
            for (final music in musics) {
              _musicMap.set(music.musicId.toString(), music);
            }
            _notifyMusicListeners();
          } catch (e) {
            print('Failed to load initial playlist state: $e');
            completer.completeError(e);
            return;
          }

          stompClient!.subscribe(
            destination: '/topic/team-playlists/$playlistId',
            callback: (frame) {
              if (frame.body == null) return;
              final data = json.decode(frame.body!);
              _handleStompMessage(data);
            },
          );
          _currentPlaylistId = playlistId;  // 현재 플레이리스트 ID 설정
          _updateConnectionState(true);
          completer.complete();
        },
        onWebSocketError: (error) {
          print('WebSocket Error: $error');
          _updateConnectionState(false);
          completer.completeError(error);
        },
        onDisconnect: (_) {
          _updateConnectionState(false);
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken'
        },
      ),
    );

    stompClient!.activate();
    return completer.future;
  }

  Future<void> ensureStompConnection(int playlistId) async {
    if (_currentPlaylistId!=null && _currentPlaylistId!=playlistId){
      await disconnect();
    }

    if(stompClient == null || !stompClient!.connected) {
      await _initializeStompClient(playlistId);
    }
  }
  Future<void> addTeamPlaylistMusics(int playlistId, int musicId) async {
    await ensureStompConnection(playlistId);
    await _apiService.addTeamPlaylistMusics(playlistId, musicId);

    final musics = await _apiService.getTeamPlaylistMusics(playlistId);
    final addedMusic = musics.firstWhere((music) => music.musicId == musicId);

    _musicMap.set(musicId.toString(), addedMusic);

    // state를 전송 가능한 형태로 변환
    final serializedState = _musicMap.state.map((key, value) {
      final List<dynamic> stateList = value as List<dynamic>;
      if (stateList[2] != null && stateList[2] is TeamPlaylistMusicDto) {
        stateList[2] = (stateList[2] as TeamPlaylistMusicDto).toJson();
      }
      return MapEntry(key, stateList);
    });

    stompClient!.send(
      destination: '/app/team-playlists/$playlistId',
      body: json.encode({
        'type': 'state',
        'state': serializedState,
      }),
    );
  }
  Future<void> deleteTeamPlaylistMusics(int playlistId, List<int> musicIds) async {
    await ensureStompConnection(playlistId);
    await _apiService.deleteTeamPlaylistMusics(playlistId, musicIds);

    for (final musicId in musicIds) {
      _musicMap.delete(musicId.toString());
    }

    final serializedState = _musicMap.state.map((key, value) {
      final List<dynamic> stateList = value as List<dynamic>;
      if (stateList[2] != null && stateList[2] is TeamPlaylistMusicDto) {
        stateList[2] = (stateList[2] as TeamPlaylistMusicDto).toJson();
      }
      return MapEntry(key, stateList);
    });

    stompClient!.send(
      destination: '/app/team-playlists/$playlistId',
      body: json.encode({
        'type': 'state',
        'state': serializedState,
      }),
    );
  }
  Future<void> updateTeamPlaylistOrder(int playlistId, List<Map<String, dynamic>> updateMusic) async {
    await ensureStompConnection(playlistId);
    await _apiService.updateTeamPlaylistOrder(playlistId, updateMusic);

    final musics = await _apiService.getTeamPlaylistMusics(playlistId);

    for (final music in musics) {
      _musicMap.set(music.musicId.toString(), music);
    }

    final serializedState = _musicMap.state.map((key, value) {
      final List<dynamic> stateList = value as List<dynamic>;
      if (stateList[2] != null && stateList[2] is TeamPlaylistMusicDto) {
        stateList[2] = (stateList[2] as TeamPlaylistMusicDto).toJson();
      }
      return MapEntry(key, stateList);
    });

    stompClient!.send(
      destination: '/app/team-playlists/$playlistId',
      body: json.encode({
        'type': 'state',
        'state': serializedState,
      }),
    );
  }

  Stream<List<TeamPlaylistMusicDto>> get musicStream => _musicStreamController.stream;

  Future<void> disconnect() async{
    stompClient?.deactivate();
    stompClient = null;
    _currentPlaylistId = null;
    _updateConnectionState(false);
    _musicMap = LWWMap<TeamPlaylistMusicDto>(_musicMap.id, {});  // CRDT 상태 초기화
  }

  void dispose() {
    disconnect();
    _musicStreamController.close();
  }

  bool get isConnected => stompClient?.connected ?? false;

  Future<void> reconnect(int playlistId) async {
    await disconnect();
    await ensureStompConnection(playlistId);
  }

  // 연결 상태 스트림 추가
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;

  void _updateConnectionState(bool connected) {
    _connectionStateController.add(connected);
  }

  inviteFriend({required int teamPlaylistId, required int friendId}) {}

  getFriends() {}
}